#!/usr/bin/env bash
set -Eeuo pipefail
NS=aceest-fitness
DEPLOYMENT="${1:-aceest-fitness-blue}"
kubectl get deployment "$DEPLOYMENT" -n "$NS" >/dev/null
kubectl rollout undo "deployment/$DEPLOYMENT" -n "$NS"
kubectl rollout status "deployment/$DEPLOYMENT" -n "$NS" --timeout=180s
echo "Rollback verified for $DEPLOYMENT."
