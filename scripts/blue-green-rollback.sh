#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="aceest-fitness"
SERVICE="aceest-fitness-service"
APP_LABEL="aceest-fitness"
CONTAINER_PORT=5000
ROLLOUT_TIMEOUT="180s"
ENDPOINT_TIMEOUT=60

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

command -v kubectl >/dev/null 2>&1 || fail "kubectl is required"

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 \
    || fail "Namespace $NAMESPACE does not exist"

kubectl get service "$SERVICE" -n "$NAMESPACE" >/dev/null 2>&1 \
    || fail "Service $SERVICE does not exist"

ACTIVE_COLOR="$(
    kubectl get service "$SERVICE" -n "$NAMESPACE" \
        -o jsonpath='{.spec.selector.deployment-color}'
)"

case "$ACTIVE_COLOR" in
    blue) PREVIOUS_COLOR="green" ;;
    green) PREVIOUS_COLOR="blue" ;;
    *) fail "Service has an invalid or missing deployment-color selector." ;;
esac

ACTIVE_DEPLOYMENT="aceest-fitness-${ACTIVE_COLOR}"
PREVIOUS_DEPLOYMENT="aceest-fitness-${PREVIOUS_COLOR}"

ACTIVE_POD="$(
    kubectl get pods -n "$NAMESPACE" \
        -l "app=$APP_LABEL,deployment-color=$ACTIVE_COLOR" \
        -o jsonpath='{.items[0].metadata.name}'
)"

[[ -n "$ACTIVE_POD" ]] || fail "Currently active pod was not found."

log "Currently active colour: $ACTIVE_COLOR"
log "Rollback target colour: $PREVIOUS_COLOR"

kubectl get deployment "$ACTIVE_DEPLOYMENT" -n "$NAMESPACE" \
    >/dev/null 2>&1 || fail "Currently active deployment does not exist"

kubectl get deployment "$PREVIOUS_DEPLOYMENT" -n "$NAMESPACE" \
    >/dev/null 2>&1 || fail "Rollback target deployment does not exist"

log "Checking rollback target deployment readiness..."

kubectl rollout status "deployment/$PREVIOUS_DEPLOYMENT" \
    -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT" \
    || fail "Rollback target deployment is not Ready. Traffic was not changed."

kubectl wait pod \
    -n "$NAMESPACE" \
    -l "app=$APP_LABEL,deployment-color=$PREVIOUS_COLOR" \
    --for=condition=Ready \
    --timeout="$ROLLOUT_TIMEOUT" \
    || fail "Rollback target pod did not become Ready. Traffic was not changed."

PREVIOUS_POD="$(
    kubectl get pods -n "$NAMESPACE" \
        -l "app=$APP_LABEL,deployment-color=$PREVIOUS_COLOR" \
        -o jsonpath='{.items[0].metadata.name}'
)"

[[ -n "$PREVIOUS_POD" ]] || fail "Rollback target pod was not found."

log "Checking rollback target application and database health..."

kubectl exec "$PREVIOUS_POD" -n "$NAMESPACE" -- \
    python -c "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:${CONTAINER_PORT}/health', timeout=5); print(r.read().decode())" \
    || fail "Rollback target health check failed. Traffic was not changed."

log "Switching Service traffic to $PREVIOUS_COLOR..."

if ! kubectl patch service "$SERVICE" -n "$NAMESPACE" \
    --type=merge \
    -p "{\"spec\":{\"selector\":{\"app\":\"$APP_LABEL\",\"deployment-color\":\"$PREVIOUS_COLOR\"}}}"; then
    fail "Service update failed. The original selector should remain active."
fi

log "Verifying rollback Service endpoint..."

if verify_endpoint "$PREVIOUS_POD"; then
    log "SUCCESS: Traffic restored to $PREVIOUS_COLOR."
    log "Serving pod: $PREVIOUS_POD"
    exit 0
fi

log "ERROR: Rollback endpoint verification failed."
log "Attempting to restore the original colour: $ACTIVE_COLOR."

if ! kubectl patch service "$SERVICE" -n "$NAMESPACE" \
    --type=merge \
    -p "{\"spec\":{\"selector\":{\"app\":\"$APP_LABEL\",\"deployment-color\":\"$ACTIVE_COLOR\"}}}"; then
    fail "CRITICAL: Could not restore the original Service selector. Manual intervention required."
fi

log "Verifying original Service endpoint restoration..."

if verify_endpoint "$ACTIVE_POD"; then
    log "Original Service endpoint successfully restored."
else
    fail "CRITICAL: Original Service endpoint could not be verified. Manual intervention required."
fi

fail "Rollback could not be completed. Original traffic selector was restored."