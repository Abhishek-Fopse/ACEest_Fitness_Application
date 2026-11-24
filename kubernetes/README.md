# ACEest Fitness - Kubernetes Blue-Green Deployment

## Architecture

The application uses two Kubernetes Deployments to support Blue-Green releases.

| Component | Resource |
|---|---|
| Namespace | aceest-fitness |
| Blue deployment | aceest-fitness-blue |
| Green deployment | aceest-fitness-green |
| Service | aceest-fitness-service |
| Service type | ClusterIP |
| Persistent storage | 1Gi PersistentVolumeClaim |
| PVC | aceest-fitness-data |
| Application port | 5000 |
| Readiness endpoint | /health |
| Liveness endpoint | /live |
| Container UID/GID | 10001 |

The Service initially selects Blue. Green starts with zero replicas.

During a deployment, the inactive colour is updated and started. Its readiness and application health are checked before the Service selector is changed.

The previous deployment remains running after a successful switch to support rollback.

## Prerequisites

- Kubernetes cluster with kubectl configured
- Docker Hub image available
- Default StorageClass supporting persistent volume provisioning
- PersistentVolumeClaim with ReadWriteOnce access
- Git Bash or another Bash environment for deployment scripts

All commands below are intended for a Linux shell and should be run from the project root.

## 1. Create namespace

    kubectl apply -f kubernetes/namespace.yaml

## 2. Create application secret

Generate a strong random secret. Do not commit the secret to Git.

    SECRET=$(openssl rand -base64 32)

    kubectl create secret generic aceest-fitness-secret \
      --namespace aceest-fitness \
      --from-literal=flask-secret-key="$SECRET" \
      --dry-run=client -o yaml | kubectl apply -f -

    unset SECRET

## 3. Apply configuration and persistent storage

    kubectl apply -f kubernetes/configmap.yaml
    kubectl apply -f kubernetes/persistent-volume-claim.yaml

Verify the PVC:

    kubectl get pvc -n aceest-fitness

Wait for it to become Bound before proceeding.

## 4. Migrate from the original deployment, if present

The original deployment was named aceest-fitness.

It must not run alongside the Blue-Green deployments because all deployments use the same SQLite database volume.

If the original deployment exists, scale it down and remove its Deployment resource:

    kubectl scale deployment/aceest-fitness \
      --replicas=0 -n aceest-fitness

    kubectl delete deployment aceest-fitness \
      -n aceest-fitness

Check that the original deployment's pods have terminated. The selector below excludes Blue and Green pods:

    kubectl get pods -n aceest-fitness -l 'app=aceest-fitness,!deployment-color'

    kubectl wait --for=delete pod \
      -l 'app=aceest-fitness,!deployment-color' \
      -n aceest-fitness --timeout=180s

Do not proceed while an old application pod is still running.

The PVC is not deleted by removing the Deployment. Existing database data remains on the persistent volume.

## 5. Create Blue and Green deployments

Choose a specific published Docker Hub image tag. Do not use the mutable latest tag for the initial deployment.

Before applying the Blue manifest, change its image field in kubernetes/deployment.yaml to the selected published tag:

    image: abhishekfopse/aceest-fitness:<published-image-tag>

Apply both deployment manifests:

    kubectl apply -f kubernetes/deployment.yaml
    kubectl apply -f kubernetes/green-deployment.yaml

Apply the Service:

    kubectl apply -f kubernetes/service.yaml

Blue starts with one replica using the selected image. Green starts with zero replicas.

The Service initially routes traffic to Blue.

Wait for Blue:

    kubectl rollout status deployment/aceest-fitness-blue \
      -n aceest-fitness --timeout=180s

Verify the initial Service selector:

    kubectl get service aceest-fitness-service \
      -n aceest-fitness \
      -o jsonpath='{.spec.selector}'

The selector should contain deployment-color=blue.

## 7. Verify the application

    kubectl get deployments -n aceest-fitness
    kubectl get pods -n aceest-fitness
    kubectl get services -n aceest-fitness
    kubectl get endpoints aceest-fitness-service -n aceest-fitness
    kubectl get pvc -n aceest-fitness

Check Blue application logs:

    kubectl logs deployment/aceest-fitness-blue -n aceest-fitness

Check Green application logs:

    kubectl logs deployment/aceest-fitness-green -n aceest-fitness

## 8. Deploy a new version using Blue-Green

The CI pipeline publishes Docker images with build-number, commit and latest tags.

Use a specific published tag for deployment.

    bash scripts/blue-green-deploy.sh <docker-image-tag>

The script:

1. Identifies the currently active colour from the Service.
2. Checks the active deployment.
3. Updates and starts the inactive deployment.
4. Waits for its rollout and readiness.
5. Checks the candidate application's /health endpoint.
6. Switches the Service selector to the candidate colour.
7. Verifies that the Service endpoint selects the candidate pod.

If candidate health or rollout checks fail, the active Service selector is left unchanged.

If endpoint verification fails after switching, the script attempts to restore the previous colour.

## 9. Roll back to the previous version

Run:

    bash scripts/blue-green-rollback.sh

The rollback script:

1. Identifies the currently active colour.
2. Checks that the other deployment is available and Ready.
3. Checks its application health.
4. Changes the Service selector to the previous colour.
5. Verifies the selected Service endpoint.

If rollback endpoint verification fails, the script attempts to restore the original Service selector.

## 10. Inspect Service routing and deployment status

Check the Service selector:

    kubectl get service aceest-fitness-service \
      -n aceest-fitness \
      -o jsonpath='{.spec.selector}'

Check the endpoints:

    kubectl get endpoints aceest-fitness-service -n aceest-fitness

Check deployment status:

    kubectl get deployments -n aceest-fitness

Check pod placement:

    kubectl get pods -n aceest-fitness -o wide

## 11. Access the application locally

    kubectl port-forward service/aceest-fitness-service \
      8080:80 -n aceest-fitness

Open:

    http://localhost:8080

Health endpoint:

    http://localhost:8080/health

Liveness endpoint:

    http://localhost:8080/live

Version endpoint:

    http://localhost:8080/version

## 12. Persistent storage and SQLite limitations

Both Blue and Green reference the same PersistentVolumeClaim:

    aceest-fitness-data

The database is stored at:

    /data/aceest_fitness.db

The application currently uses SQLite. Both versions may run simultaneously during Blue-Green deployment and may access the same database.

SQLite depends on correct filesystem locking behavior. ReadWriteOnce does not guarantee that concurrent access is safe, nor does it mean that multiple pods can mount the volume across different nodes.

Before using simultaneous Blue-Green pods, verify:

- The cluster storage driver supports the required mounting behavior.
- The pods can access the shared volume.
- SQLite file locking works correctly on the provisioned filesystem.
- Database schema changes remain compatible with the previous application version.

Do not assume this deployment design is production-safe until those tests pass.

## 13. Remove deployment resources

To remove the application deployments:

    kubectl delete -f kubernetes/deployment.yaml
    kubectl delete -f kubernetes/green-deployment.yaml
    kubectl delete -f kubernetes/service.yaml

WARNING: Deleting the namespace also deletes its PVC and associated Kubernetes resources. Persistent application data may be lost.

    kubectl delete namespace aceest-fitness
