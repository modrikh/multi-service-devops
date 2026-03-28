# Argo CD GitOps Setup (Dev + Prod)

This folder contains Argo CD bootstrap resources using an app-of-apps pattern with two root applications:

- `root-application-dev.yaml` for the `dev` branch.
- `root-application-prod.yaml` for the `main` branch.

Both roots reuse the same child apps in `k8s/argocd/apps`.

## Files

- `project.yaml`: Shared Argo CD project.
- `root-application-dev.yaml`: Root application for dev (`targetRevision: dev`).
- `root-application-prod.yaml`: Root application for prod (`targetRevision: main`).
- `apps/*.yaml`: Child applications for base, database, services, and ingress.

## Bootstrap Steps

1. Install Argo CD in your cluster:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. Update `repoURL` in:
   - `k8s/argocd/project.yaml`
   - `k8s/argocd/root-application-dev.yaml`
   - `k8s/argocd/root-application-prod.yaml`
   - all files under `k8s/argocd/apps/`

3. Apply shared project:
   ```bash
   kubectl apply -f k8s/argocd/project.yaml
   ```

4. Apply one root app per environment target:
   - Dev:
     ```bash
     kubectl apply -f k8s/argocd/root-application-dev.yaml
     ```
   - Prod:
     ```bash
     kubectl apply -f k8s/argocd/root-application-prod.yaml
     ```

## Notes

- Sync is automated (`prune` + `selfHeal`).
- Sync waves preserve deployment order:
  - 0: base
  - 1: database
  - 2: application services
  - 3: ingress
- If `dev` and `prod` are deployed to the same cluster and same namespace, they will conflict. Use separate clusters or environment-specific namespaces/manifests.
