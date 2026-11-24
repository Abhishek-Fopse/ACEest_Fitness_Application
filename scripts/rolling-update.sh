#!/usr/bin/env bash
set -Eeuo pipefail
NS="aceest-fitness"
DEPLOYMENT="${1:-aceest-fitness-blue}"
TAG="${2:-}"
IMAGE="abhishekfopse/aceest-fitness"
[[ "$TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]] || { echo "Usage: $0 <deployment-name> <image-tag>" >&2; exit 2; }
case "$DEPLOYMENT" in
  aceest-fitness-blue) OTHER="aceest-fitness-green" ;;
  aceest-fitness-green) OTHER="aceest-fitness-blue" ;;
  *) echo "Only Blue or Green deployment names are accepted." >&2; exit 2 ;;
esac
kubectl get deployment "$DEPLOYMENT" -n "$NS" >/dev/null
kubectl scale "deployment/$OTHER" --replicas=0 -n "$NS"
kubectl patch deployment "$DEPLOYMENT" -n "$NS" --type=merge \
  -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":0,"maxUnavailable":1}}}}'
kubectl set image "deployment/$DEPLOYMENT" "aceest-fitness=$IMAGE:$TAG" -n "$NS"
if kubectl rollout status "deployment/$DEPLOYMENT" -n "$NS" --timeout=180s; then
  echo "Rolling update completed. Single-replica update may briefly interrupt service."
else
  echo "Update failed; rolling back." >&2
  kubectl rollout undo "deployment/$DEPLOYMENT" -n "$NS"
  kubectl rollout status "deployment/$DEPLOYMENT" -n "$NS" --timeout=180s
  exit 1
fi
