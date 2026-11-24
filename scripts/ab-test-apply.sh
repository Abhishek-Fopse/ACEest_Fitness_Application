#!/usr/bin/env bash
set -Eeuo pipefail

NS="aceest-fitness"
GREEN="aceest-fitness-green"
IMAGE="abhishekfopse/aceest-fitness"
TAG="${1:-}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ "$TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]] \
  || fail "Usage: $0 <published-image-tag>"

[[ "${ACEEST_ALLOW_SHARED_SQLITE:-}" == "1" ]] || fail \
  "Blocked: Blue and Green share the SQLite PVC. Validate locking/concurrent access first. Only then set ACEEST_ALLOW_SHARED_SQLITE=1."

kubectl get ingressclass nginx >/dev/null 2>&1 \
  || fail "Install ingress-nginx; IngressClass nginx was not found."

if kubectl get ingress aceest-fitness-canary -n "$NS" >/dev/null 2>&1; then
  fail "Canary ingress exists. Disable Canary before enabling A/B routing."
fi

kubectl get deployment aceest-fitness-blue -n "$NS" >/dev/null \
  || fail "Blue deployment not found."
kubectl get deployment "$GREEN" -n "$NS" >/dev/null \
  || fail "Green deployment not found."

kubectl set image "deployment/$GREEN" \
  "aceest-fitness=$IMAGE:$TAG" -n "$NS"
kubectl scale "deployment/$GREEN" --replicas=1 -n "$NS"
kubectl rollout status "deployment/$GREEN" -n "$NS" --timeout=180s \
  || fail "Green deployment did not become Ready; A/B ingress was not applied."

kubectl apply -f kubernetes/ab-test-ingress.yaml

echo "A/B routing applied."
echo "Requests with X-ACEest-Variant: B are routed to Green; other requests use Blue."
echo "WARNING: Blue and Green share SQLite storage. Concurrent use must be validated."
