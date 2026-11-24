#!/usr/bin/env bash
set -Eeuo pipefail
NS="aceest-fitness"

kubectl get ingress aceest-fitness-primary -n "$NS" >/dev/null
kubectl annotate ingress aceest-fitness-primary -n "$NS" \
  nginx.ingress.kubernetes.io/mirror-target- \
  nginx.ingress.kubernetes.io/mirror-host- \
  nginx.ingress.kubernetes.io/mirror-request-body- \
  --overwrite

echo "Shadow request mirroring disabled. Primary ingress remains active."
echo "Shadow deployment and its isolated PVC are retained."
