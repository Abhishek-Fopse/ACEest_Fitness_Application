#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="aceest-fitness"
SERVICE="aceest-fitness-service"
APP_LABEL="aceest-fitness"
IMAGE_REPOSITORY="abhishekfopse/aceest-fitness"
CONTAINER_NAME="aceest-fitness"
ROLLOUT_TIMEOUT="180s"
ENDPOINT_TIMEOUT=60

IMAGE_TAG="${1:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

fail() {
    log "ERROR: $*"
    exit 1
}

verify_endpoint() {
    local expected_pod="$1"
    local endpoint_pod=""

    for ((attempt=1; attempt<=ENDPOINT_TIMEOUT; attempt++)); do
        endpoint_pod="$(
            kubectl get endpoints "$SERVICE" -n "$NAMESPACE" \
                -o jsonpath='{.subsets[0].addresses[0].targetRef.name}' \
                2>/dev/null || true
        )"

        if [[ "$endpoint_pod" == "$expected_pod" ]]; then
            return 0
        fi

        sleep 2
    done

    return 1
}

rollback_traffic() {
    log "Restoring Service traffic to $ACTIVE_COLOR..."

    if ! kubectl patch service "$SERVICE" -n "$NAMESPACE" \
        --type=merge \
        -p "{\"spec\":{\"selector\":{\"app\":\"$APP_LABEL\",\"deployment-color\":\"$ACTIVE_COLOR\"}}}"; then
        log "CRITICAL: Could not restore the previous Service selector."
        log "Manual intervention is required."
        return 1
    fi

    if verify_endpoint "$ACTIVE_POD"; then
        log "Previous Service endpoint successfully restored."
        return 0
    fi

    log "CRITICAL: Previous endpoint could not be verified."
    log "Inspect the Service and Endpoint resources manually."
    return 1
}

cleanup_candidate() {
    log "Scaling failed candidate deployment to zero..."

    kubectl scale "deployment/$CANDIDATE_DEPLOYMENT" \
        --replicas=0 -n "$NAMESPACE" || \
        log "WARNING: Candidate cleanup failed. Manual cleanup may be required."
}

if [[ -z "$IMAGE_TAG" ]]; then
    fail "Usage: $0 <docker-image-tag>"
fi

if [[ ! "$IMAGE_TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]]; then
    fail "Invalid Docker image tag: $IMAGE_TAG"
fi

command -v kubectl >/dev/null 2>&1 || fail "kubectl is required"

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 \
    || fail "Namespace $NAMESPACE does not exist"

kubectl get service "$SERVICE" -n "$NAMESPACE" >/dev/null 2>&1 \
    || fail "Service $SERVICE does not exist"

# Prevent the original deployment from accessing the shared SQLite database.
if kubectl get deployment aceest-fitness -n "$NAMESPACE" >/dev/null 2>&1; then
    BASELINE_REPLICAS="$(
        kubectl get deployment aceest-fitness -n "$NAMESPACE" \
            -o jsonpath='{.spec.replicas}'
    )"

    if [[ "$BASELINE_REPLICAS" =~ ^[0-9]+$ ]] && (( BASELINE_REPLICAS > 0 )); then
        fail "Scale the original aceest-fitness deployment to zero before proceeding."
    fi
fi

ACTIVE_COLOR="$(
    kubectl get service "$SERVICE" -n "$NAMESPACE" \
        -o jsonpath='{.spec.selector.deployment-color}'
)"

case "$ACTIVE_COLOR" in
    blue) CANDIDATE_COLOR="green" ;;
    green) CANDIDATE_COLOR="blue" ;;
    *) fail "Service has an invalid or missing deployment-color selector." ;;
esac

ACTIVE_DEPLOYMENT="aceest-fitness-${ACTIVE_COLOR}"
CANDIDATE_DEPLOYMENT="aceest-fitness-${CANDIDATE_COLOR}"
IMAGE="${IMAGE_REPOSITORY}:${IMAGE_TAG}"

log "Active deployment: $ACTIVE_DEPLOYMENT"
log "Candidate deployment: $CANDIDATE_DEPLOYMENT"
log "Candidate image: $IMAGE"

kubectl get deployment "$ACTIVE_DEPLOYMENT" -n "$NAMESPACE" \
    >/dev/null 2>&1 || fail "Active deployment does not exist"

kubectl get deployment "$CANDIDATE_DEPLOYMENT" -n "$NAMESPACE" \
    >/dev/null 2>&1 || fail "Candidate deployment does not exist"

log "Verifying active deployment health..."

kubectl rollout status "deployment/$ACTIVE_DEPLOYMENT" \
    -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT" \
    || fail "Active deployment is not healthy. Deployment cancelled."

ACTIVE_POD="$(
    kubectl get pods -n "$NAMESPACE" \
        -l "app=$APP_LABEL,deployment-color=$ACTIVE_COLOR" \
        -o jsonpath='{.items[0].metadata.name}'
)"

[[ -n "$ACTIVE_POD" ]] || fail "Active pod was not found."

# Stop the inactive deployment and wait for its old pods to terminate.
log "Preparing candidate deployment..."

kubectl scale "deployment/$CANDIDATE_DEPLOYMENT" \
    --replicas=0 -n "$NAMESPACE"

OLD_CANDIDATE_PODS="$(
    kubectl get pods -n "$NAMESPACE" \
        -l "app=$APP_LABEL,deployment-color=$CANDIDATE_COLOR" \
        -o name
)"

if [[ -n "$OLD_CANDIDATE_PODS" ]]; then
    kubectl wait pod \
        -n "$NAMESPACE" \
        -l "app=$APP_LABEL,deployment-color=$CANDIDATE_COLOR" \
        --for=delete \
        --timeout="$ROLLOUT_TIMEOUT" \
        || fail "Old candidate pods did not terminate."
fi

# Update the image while the candidate is stopped.
kubectl set image "deployment/$CANDIDATE_DEPLOYMENT" \
    "$CONTAINER_NAME=$IMAGE" -n "$NAMESPACE"

CONFIGURED_IMAGE="$(
    kubectl get deployment "$CANDIDATE_DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="aceest-fitness")].image}'
)"

[[ "$CONFIGURED_IMAGE" == "$IMAGE" ]] \
    || fail "Candidate image verification failed. Expected $IMAGE, found $CONFIGURED_IMAGE."

log "Verified candidate image: $CONFIGURED_IMAGE"

# Start the candidate only after the image has been verified.
kubectl scale "deployment/$CANDIDATE_DEPLOYMENT" \
    --replicas=1 -n "$NAMESPACE"

log "Waiting for candidate rollout..."

if ! kubectl rollout status "deployment/$CANDIDATE_DEPLOYMENT" \
    -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"; then
    cleanup_candidate
    fail "Candidate rollout failed. Existing traffic remains unchanged."
fi

kubectl wait pod \
    -n "$NAMESPACE" \
    -l "app=$APP_LABEL,deployment-color=$CANDIDATE_COLOR" \
    --for=condition=Ready \
    --timeout="$ROLLOUT_TIMEOUT" \
    || {
        cleanup_candidate
        fail "Candidate pod did not become Ready."
    }

POD_NAME="$(
    kubectl get pods -n "$NAMESPACE" \
        -l "app=$APP_LABEL,deployment-color=$CANDIDATE_COLOR" \
        -o jsonpath='{.items[0].metadata.name}'
)"

[[ -n "$POD_NAME" ]] || {
    cleanup_candidate
    fail "Candidate pod was not found."
}

log "Checking candidate application and database health..."

if ! kubectl exec "$POD_NAME" -n "$NAMESPACE" -- \
    python -c "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=5); print(r.read().decode())"; then
    cleanup_candidate
    fail "Candidate health check failed. Existing traffic remains unchanged."
fi

log "Switching Service traffic to $CANDIDATE_COLOR..."

if ! kubectl patch service "$SERVICE" -n "$NAMESPACE" \
    --type=merge \
    -p "{\"spec\":{\"selector\":{\"app\":\"$APP_LABEL\",\"deployment-color\":\"$CANDIDATE_COLOR\"}}}"; then
    cleanup_candidate
    fail "Service update failed. Existing traffic should remain unchanged."
fi

log "Verifying the new Service endpoint..."

if ! verify_endpoint "$POD_NAME"; then
    log "Endpoint verification failed. Initiating traffic rollback."

    if rollback_traffic; then
        cleanup_candidate
        fail "Deployment cancelled. Previous colour restored."
    else
        fail "Automatic rollback could not be verified. Manual intervention required."
    fi
fi

log "SUCCESS: Traffic switched to $CANDIDATE_COLOR."
log "Candidate image: $IMAGE"
log "Serving pod: $POD_NAME"
log "Previous deployment remains available for rollback."