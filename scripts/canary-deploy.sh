#!/usr/bin/env bash
set -Eeuo pipefail
NS="aceest-fitness"
GREEN="aceest-fitness-green"
TAG="${1:-}"
WEIGHT="${2:-25}"
IMAGE="abhishekfopse/aceest-fitness"
[[ "$TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]] || { echo "Usage: $0 <image-tag> [weight-0-100]" >&2; exit 2; }
[[ "$WEIGHT" =~ ^([0-9]|[1-9][0-9]|100)$ ]] || { echo "Weight must be 0-100" >&2; exit 2; }
[[ "${ACEEST_ALLOW_SHARED_SQLITE:-}" == "1" ]] || {
  echo "Blocked: Blue and Green share the SQLite PVC. Verify locking/concurrent access first." >&2
  echo "Only after explicit VM validation, set ACEEST_ALLOW_SHARED_SQLITE=1 and retry." >&2
  exit 3
}
kubectl get ingressclass nginx >/dev/null 2>&1 || { echo "NGINX IngressClass is required." >&2; exit 1; }
kubectl get deployment aceest-fitness-blue -n "$NS" >/dev/null
kubectl get deployment "$GREEN" -n "$NS" >/dev/null
kubectl set image "deployment/$GREEN" "aceest-fitness=$IMAGE:$TAG" -n "$NS"
kubectl scale "deployment/$GREEN" --replicas=1 -n "$NS"
kubectl rollout status "deployment/$GREEN" -n "$NS" --timeout=180s
kubectl apply -f kubernetes/canary-ingress.yaml
kubectl annotate ingress aceest-fitness-canary -n "$NS" nginx.ingress.kubernetes.io/canary-weight="$WEIGHT" --overwrite
echo "Canary configured at ${WEIGHT}% by NGINX Ingress."
echo "This is weighted HTTP routing. Shared SQLite concurrency was explicitly acknowledged."
