# ACEest Fitness - DevOps Assignment 2

## CI/CD architecture
GitHub stores source code. Jenkins checks out the repository, performs Python syntax/lint checks, runs pytest in a container, performs SonarQube analysis and enforces the quality gate. Successful builds publish versioned Docker images to Docker Hub.

## Containerization
The Flask application uses a multi-stage Dockerfile. The production image runs as a non-root user and exposes health and liveness endpoints. The test stage runs pytest and produces JUnit-compatible results.

## Deployment strategies
- Blue-Green: Blue and Green Deployments; Service selector changes after candidate health checks.
- Canary: stable and candidate replicas are temporarily exposed through one Service. Distribution is approximate and not deterministic weighted routing.
- Shadow: helper script manually replays supplied GET requests to a shadow endpoint. It does not transparently mirror live ingress traffic.
- A/B: NGINX Ingress header routing sends `X-ACEest-Variant: B` requests to Green. Requires ingress-nginx.
- Rolling update: Kubernetes rolling update with rollout status and rollback on failure.
- Rollback: Kubernetes rollout history restores the previous ReplicaSet.

## Challenges and mitigations
The application uses SQLite. Concurrent versions sharing a persistent volume can create file-locking and write-contention risks. ReadWriteOnce does not prove safe concurrent SQLite access. Validate the actual VM storage driver and filesystem before concurrent versions are used.

## Evidence to capture after VM validation
GitHub commits, Jenkins successful runs, JUnit results, SonarQube quality gate, Docker Hub image tags, Kubernetes Pods/Services/Ingress/rollout status, and genuine success/failure/rollback screenshots.

## Limitations
Shadow replay is manual GET replay, canary replica distribution is approximate, and A/B requires ingress-nginx. Do not claim cluster success until VM tests pass.
