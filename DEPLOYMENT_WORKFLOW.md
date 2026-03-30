# 🚀 Deployment Workflow Guide

Follow these steps in order to provision the new Container Registry (ACR), build and push your Docker images, connect to your Kubernetes cluster (AKS), and deploy your services.

## 1. Apply Terraform Infrastructure Updates

We recently added an **Azure Container Registry (ACR)** to your Terraform configuration. You must apply this change first so the registry exists.

```bash
cd ~/multi-service-devops

# Apply terraform changes (skipping Ansible since VMs are already configured)
./deploy.sh --skip-ansible
```

## 2. Connect to AKS (Kubernetes)

Once Terraform finishes, you need to configure `kubectl` to talk to your new AKS cluster.

```bash
az aks get-credentials \
  --resource-group rg-multi-service-dev \
  --name multi-service-devops-dev-k8s \
  --overwrite-existing
```

**Verify the connection:**
```bash
kubectl get nodes
```
*(You should see 1 node in the `Ready` status).*

## 3. Build, Push, and Patch Images

We created an automated script to build all local Docker images, push them to your new ACR, and update your `k8s/` manifests to point to the new registry URLs.

```bash
# Make the script executable
chmod +x build.sh

# Run the build script
./build.sh
```

**What this does:**
1. Dynamically reads your ACR login server from Terraform output.
2. Logs Docker into ACR using your Azure credentials (`az acr login`).
3. Builds all 7 service images concurrently.
4. Pushes them to ACR.
5. Replaces `image: auth-service:latest` in your `k8s/` YAMLs with `image: youracr.azurecr.io/auth-service:latest`.

## 4. Deploy to Kubernetes

You have **two options** to deploy your updated manifests to the AKS cluster.

### Option A: The GitOps Way (Using Argo CD - Recommended)

Since this project is designed around GitOps, Argo CD should be the one applying your manifests, not you manually typing `kubectl apply`.

1. **Commit and push your changes to Git:**
   Because `build.sh` modified your `k8s/` files to point to the new ACR, Argo CD needs to see those changes in GitHub/GitLab before it can deploy them.
   ```bash
   git add k8s/
   git commit -m "chore: update k8s manifests with new ACR image paths"
   git push origin dev
   ```

2. **Install Argo CD on your cluster:**
   *(Note: Note the `--server-side` flag. Argo CD has massive CRDs that exceed Kubernetes' client-side apply limits).*
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

3. **Bootstrap your applications:**
   Point Argo CD at your repository, and it will deploy the database, network, and all 7 microservices automatically in the correct order.
   ```bash
   kubectl apply -f k8s/argocd/project.yaml
   kubectl apply -f k8s/argocd/root-application-dev.yaml
   ```

*(You can check the sync progress dynamically using `kubectl get applications -n argocd`)*

### Accessing the Argo CD UI

To monitor your deployments visually from your browser:

1. **Port-forward the Argo CD server to your local machine:**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

2. **Retrieve the auto-generated admin password:**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
   ```

3. **Log in:**
   Open your browser and navigate to `https://localhost:8080` (accept the self-signed certificate warning).
   - **Username:** `admin`
   - **Password:** *(the output from step 2)*

---

### Option B: The Manual Way (Direct `kubectl apply`)

If you just want to test quickly without committing to Git or setting up Argo CD yet, you can force the deployment directly:

```bash
# 1. Base config and database
kubectl apply -f k8s/base/
kubectl apply -f k8s/database/

# 2. Deploy services
kubectl apply -f k8s/auth-service/
kubectl apply -f k8s/core-service/
kubectl apply -f k8s/user-service/
kubectl apply -f k8s/task-service/
kubectl apply -f k8s/notification-service/
kubectl apply -f k8s/frontend/

# 3. Ingress
kubectl apply -f k8s/gateway.yaml/
```

## 5. Verify the Deployment

Check that all pods are running successfully:

```bash
kubectl get pods -n devops-app
```

Check the logs of the core-service to ensure it connected to the database:
```bash
kubectl logs -l app=core-service -n devops-app
```

Check the external IP assigned to your Ingress controller:
```bash
kubectl get ingress -n devops-app
```

*(You can then map that IP to `devops.local` in your `/etc/hosts` file and navigate to `http://devops.local` in your browser).*
