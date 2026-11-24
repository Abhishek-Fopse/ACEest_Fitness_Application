#!/usr/bin/env bash
set -Eeuo pipefail
NS="aceest-fitness"

kubectl delete ingress aceest-fitness-variant-b -n "$NS" --ignore-not-found
kubectl scale deployment/aceest-fitness-green --replicas=0 -n "$NS"

echo "A/B variant routing disabled. Blue primary ingress remains."
