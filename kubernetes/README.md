# ACEest Fitness - Kubernetes Deployment

## Components
- Namespace: aceest-fitness
- Deployment: aceest-fitness
- Replicas: 1
- Service: aceest-fitness-service
- Service type: ClusterIP
- Persistent storage: 1Gi PVC
- Application port: 5000
- Readiness endpoint: /health
- Liveness endpoint: /live
- Container UID/GID: 10001

## Prerequisites
- Kubernetes cluster
- kubectl configured
- Published application image in Docker Hub
- Default StorageClass supporting persistent volume provisioning

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

## 3. Apply configuration and storage

    kubectl apply -f kubernetes/configmap.yaml
    kubectl apply -f kubernetes/persistent-volume-claim.yaml

## 4. Deploy application

    kubectl apply -f kubernetes/deployment.yaml
    kubectl apply -f kubernetes/service.yaml

## 5. Verify deployment

    kubectl get pods -n aceest-fitness
    kubectl get services -n aceest-fitness
    kubectl get pvc -n aceest-fitness
    kubectl rollout status deployment/aceest-fitness -n aceest-fitness

## 6. View application logs

    kubectl logs deployment/aceest-fitness -n aceest-fitness

## 7. Access application locally

    kubectl port-forward service/aceest-fitness-service 8080:80 -n aceest-fitness

Open http://localhost:8080

Readiness: http://localhost:8080/health

Liveness: http://localhost:8080/live

## 8. Verify persistent volume

    kubectl describe pod -l app=aceest-fitness -n aceest-fitness

Check application logs and confirm that the database initializes successfully.

## 9. Remove deployment

WARNING: Deleting the namespace also deletes its PVC and associated Kubernetes resources. Persistent data may be lost.

    kubectl delete namespace aceest-fitness
