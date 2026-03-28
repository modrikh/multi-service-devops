# multi-service-devops

End-to-end platform project using microservices, Docker, Kubernetes, Argo CD (GitOps), Terraform (AzureRM), and Ansible.

## Project Layout

- `services/`: application services (`auth`, `core`, `user`, `task`, `notification`, `frontend`, `api-gateway`).
- `k8s/`: Kubernetes manifests (base, services, database, ingress, Argo CD bootstrap).
- `helm/`: Helm charts (`auth-chart`, `user-chart`, `platform-chart`).
- `terraform/`: infrastructure as code (modules + `envs/dev|staging|prod`).
- `ansible/`: host provisioning playbooks and roles.

## Quick Start (Local with Docker Compose)

Start all services:

```bash
docker compose up --build
```

Stop and cleanup:

```bash
docker compose down -v
```

Gateway entrypoint:

- `http://127.0.0.1:8000/`

Health endpoints:

- `http://127.0.0.1:8000/healthz`
- `http://127.0.0.1:8001/healthz` (auth)
- `http://127.0.0.1:8002/healthz` (core)
- `http://127.0.0.1:8003/healthz` (user)
- `http://127.0.0.1:8004/healthz` (task)
- `http://127.0.0.1:8005/healthz` (notification)
- `http://127.0.0.1:8006/healthz` (frontend)

## Kubernetes Apply (Direct)

Apply everything under `k8s`:

```bash
kubectl apply -R -f k8s
```

Apply app namespace manifests only:

```bash
kubectl apply -f k8s/base && \
kubectl apply -f k8s/database && \
kubectl apply -f k8s/auth-service && \
kubectl apply -f k8s/user-service && \
kubectl apply -f k8s/task-service && \
kubectl apply -f k8s/notification-service && \
kubectl apply -f k8s/frontend && \
kubectl apply -f k8s/gateway.yaml
```

Check status:

```bash
kubectl get pods -n devops-app
```

## Argo CD GitOps

Install Argo CD and bootstrap project/root apps:

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f k8s/argocd/project.yaml
kubectl apply -f k8s/argocd/root-application-dev.yaml
kubectl apply -f k8s/argocd/root-application-prod.yaml
```

List Argo CD apps:

```bash
kubectl get applications -n argocd
```

## Terraform (AzureRM)

Example for dev:

```bash
cd terraform/envs/dev
terraform init
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Ansible

Configure inventory with VM IPs, then run:

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

## GitLab CI

Pipeline file: `.gitlab-ci.yml`

Stages:

- `validate`: Python syntax, Terraform validate, YAML lint
- `build`: Docker image builds for all services
