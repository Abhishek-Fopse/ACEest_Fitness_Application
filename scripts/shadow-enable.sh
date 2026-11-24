#!/usr/bin/env bash
set -Eeuo pipefail
NS="aceest-fitness"
kubectl get deployment aceest-fitness-shadow -n "$NS" >/dev/null
kubectl rollout status deployment/aceest-fitness-shadow -n "$NS" --timeout=180s
kubectl apply -f kubernetes/primary-ingress.yaml
kubectl get ingress aceest-fitness-primary -n "$NS" >/dev/null
kubectl annotate ingress aceest-fitness-primary -n "$NS" \
  nginx.ingress.kubernetes.io/mirror-target='http://aceest-fitness-shadow-service.aceest-fitness.svc.cluster.local:80$request_uri' \
  nginx.ingress.kubernetes.io/mirror-host='$host' \
  nginx.ingress.kubernetes.io/mirror-request-body='on' --overwrite
echo "NGINX request mirroring enabled. Mirrored writes go to the isolated shadow SQLite PVC."
