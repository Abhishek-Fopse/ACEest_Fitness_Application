# Deployment strategy instructions

Prerequisites: namespace `aceest-fitness`, Blue and Green Deployments, Docker Hub image, NGINX Ingress Controller with IngressClass `nginx`, and correct kubectl context.

## Canary
`bash scripts/canary-deploy.sh <image-tag> [weight-0-100]`
This configures NGINX weighted canary routing (default 25%). The script deliberately refuses to enable traffic unless `ACEEST_ALLOW_SHARED_SQLITE=1` is set, because Blue and Green share the SQLite PVC. Set that variable only after validating storage locking and concurrent access on the target VM. Disable with `bash scripts/canary-disable.sh`.

## Shadow
Deploy an isolated shadow application and SQLite PVC with `bash scripts/shadow-deploy.sh <image-tag>`. Enable live NGINX request mirroring with `bash scripts/shadow-enable.sh`; disable mirroring with `bash scripts/shadow-disable.sh`. The shadow app uses its own PVC so mirrored writes do not mutate the primary database. Validate the ingress-nginx mirror behavior before relying on it.

## A/B
Install ingress-nginx, point `aceest-fitness.local` to the ingress address, ensure Blue and Green are ready, then run `bash scripts/ab-test-apply.sh`. Header `X-ACEest-Variant: B` selects Green. Do not run Canary and A/B ingress configurations simultaneously for the same host/path.

## Rolling update
`bash scripts/rolling-update.sh <deployment-name> <image-tag>`. The script scales the opposite color to zero and uses maxSurge=0/maxUnavailable=1 to avoid simultaneous color pods sharing the SQLite PVC. A single-replica update can briefly interrupt service.

## Rollback
`bash scripts/rollback-deployment.sh <deployment-name>` uses Kubernetes rollout history.

## SQLite and storage warning
Blue and Green deployments mount the same SQLite PVC. Do not run them concurrently until the target storage's locking and application concurrency behavior have been tested. The shadow deployment has a separate PVC. These are assignment/lab implementations, not production readiness guarantees.
