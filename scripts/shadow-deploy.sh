#!/usr/bin/env bash
set -Eeuo pipefail
NS="aceest-fitness"
TAG="${1:-}"
[[ "$TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]] || { echo "Usage: $0 <image-tag>" >&2; exit 2; }
kubectl apply -f kubernetes/shadow-deployment.yaml
kubectl set image deployment/aceest-fitness-shadow "aceest-fitness=abhishekfopse/aceest-fitness:$TAG" -n "$NS"
kubectl rollout status deployment/aceest-fitness-shadow -n "$NS" --timeout=180s
echo "Isolated shadow deployment is ready with its own SQLite PVC."
