#!/usr/bin/env bash
set -Eeuo pipefail
NS="aceest-fitness"
kubectl delete ingress aceest-fitness-canary -n "$NS" --ignore-not-found
kubectl scale deployment/aceest-fitness-green --replicas=0 -n "$NS"
echo "Canary route removed; Blue primary ingress remains."
