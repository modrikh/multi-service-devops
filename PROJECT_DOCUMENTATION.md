# 📘 Project Documentation: `multi-service-devops`

> An end-to-end cloud-native platform using **microservices**, **Docker**, **Kubernetes**, **GitOps (Argo CD)**, **Infrastructure as Code (Terraform)**, and **Configuration Management (Ansible)**.

---

## 📑 Table of Contents

1. [Project Overview](#-project-overview)
2. [Architecture Overview](#-architecture-overview)
3. [Folder: /services](#-folder-services)
   - [auth-service](#-auth-service)
   - [core-service](#-core-service)
   - [user-service](#-user-service)
   - [task-service](#-task-service)
   - [notification-service](#-notification-service)
   - [frontend](#-frontend)
   - [api-gateway](#-api-gateway)
4. [Folder: /k8s](#-folder-k8s)
   - [base](#-k8sbase)
   - [auth-service (k8s)](#-k8sauth-service)
   - [database](#-k8sdatabase)
   - [gateway.yaml](#-k8sgateway)
   - [argocd](#-k8sargocd)
5. [Folder: /ansible](#-folder-ansible)
6. [Folder: /terraform](#-folder-terraform)
7. [CI/CD: GitHub Actions](#-cicd-github-actions)
8. [Root-Level Files](#-root-level-files)
9. [Tools & Technologies](#%EF%B8%8F-tools--technologies)
10. [Configuration Keys Reference](#-configuration-keys-reference)
11. [Request Flow Walkthrough](#-request-flow-walkthrough)

---

## 📁 Project Overview

**Project Type:** Cloud-Native Microservices Platform with full DevOps lifecycle

This project is a complete, production-grade reference architecture. It demonstrates how to:

- Build multiple independent, loosely coupled API services in Python (FastAPI)
- Run everything locally using Docker Compose
- Deploy to Kubernetes with declarative manifests
- Automate cluster provisioning on Azure using Terraform
- Prepare virtual machines using Ansible
- Continuously integrate and validate code using GitHub Actions CI
- Manage deployments using GitOps principles with Argo CD

### Top-Level Structure

```
multi-service-devops/
├── services/           ← Application source code (7 microservices)
├── k8s/                ← Kubernetes manifests for cluster deployment
├── terraform/          ← Azure infrastructure provisioning (IaC)
├── ansible/            ← VM configuration management playbooks & roles
├── .github/workflows/  ← GitHub Actions CI pipeline
├── docker-compose.yml  ← Local development orchestration
└── README.md           ← Project entry point and quick-start guide
```

---

## 🏗 Architecture Overview

```
                           ┌─────────────────────┐
                           │     Internet /       │
                           │     Browser          │
                           └────────┬────────────┘
                                    │ HTTP :8000
                           ┌────────▼────────────┐
                           │    API Gateway       │
                           │  (FastAPI + httpx)   │
                           └────┬───┬──┬──┬──┬───┘
                                │   │  │  │  │  │
              ┌─────────────────┘   │  │  │  │  └──────────────┐
              │ /auth/*             │  │  │  │ /notifications/* │
     ┌────────▼──────┐   /core/*   │  │  │  │         ┌────────▼──────────────┐
     │  auth-service │    ┌────────▼──┐  │  │         │  notification-service │
     │   :8001       │    │core-service│  │  │         │       :8005           │
     └───────────────┘    │  :8002    │  │  │         └───────────────────────┘
                          └────┬──────┘  │  │
                               │ SQL     │  │ /users/*
                    ┌──────────▼──────┐  │  │
                    │   PostgreSQL     │  │  └──────────┐
                    │   :5432         │  │              │
                    └─────────────────┘  │ /tasks/*    │
                                         │      ┌──────▼───────┐
                                ┌────────▼──┐   │ task-service  │
                                │user-service│   │    :8004      │
                                │   :8003   │   └──────────────┘
                                └───────────┘
```

**Design Pattern:** API Gateway → Domain Microservices  
**Communication:** Synchronous HTTP proxying (REST)  
**Database:** Shared PostgreSQL for `core-service`; in-memory for others (dev simplicity)  
**Local Dev:** `docker-compose.yml`  
**Production:** Kubernetes (AKS) via Terraform + Argo CD GitOps  

---

## 📂 Folder: `/services`

This is the heart of the application. It contains the source code for **7 independent services**, each a self-contained Python FastAPI application with its own `Dockerfile`, `main.py`, and `requirements.txt`.

Every service follows the same pattern:
- `main.py` — the entire service logic (routes, models, business rules)
- `Dockerfile` — how to build a container image for this service
- `requirements.txt` — Python library dependencies
- `README.md` — service-specific notes

---

### 🔐 auth-service

**Port:** `8001`  
**Purpose:** Handles user authentication. Issues and validates JWT tokens.

#### `main.py`

```python
SECRET_KEY = os.getenv("SECRET_KEY")  # Loaded from environment, never hardcoded
ALGORITHM = "HS256"                    # JWT signing algorithm
```

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/healthz` | Health check: returns `{"status":"ok","service":"auth"}` |
| `POST` | `/login` | Accepts `{username, password}`, returns a signed JWT token |
| `POST` | `/validate` | Accepts a JWT token, returns whether it is valid and who it belongs to |

**Key Logic:**
- Uses **PyJWT** to create tokens with a 1-hour expiry (`datetime.timedelta(hours=1)`)
- Credentials are checked against a **mocked** user store (hardcoded `admin/admin123`) — in production, this would query a database
- The `SECRET_KEY` must be injected as an environment variable at runtime; when running in Kubernetes, it comes from a `Secret` resource

**Dependencies:** `fastapi`, `uvicorn`, `pyjwt`, `pydantic`

#### `Dockerfile`

```dockerfile
FROM python:3.11-slim as runtime
RUN groupadd -r appuser && useradd -r -u 1001 -g appuser appuser  # Non-root user
...
USER 1001       # Run as UID 1001, never as root
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Security:** The container always runs as a non-root user (`UID 1001`). This is a container security best practice to limit the blast radius of any exploit.

---

### 🗄 core-service

**Port:** `8002`  
**Purpose:** Core business data layer. Manages `Item` resources and connects to PostgreSQL.

#### `main.py`

```python
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./test.db")
```

This is a **smart fallback pattern**: in production (Kubernetes), a PostgreSQL URL is injected. Locally, without the env var, it falls back to SQLite — letting developers run the service without needing a database.

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/healthz` | Returns `{"status":"ok","service":"core","database":"connected"}` |
| `POST` | `/items/` | Creates a new item in the database |
| `GET` | `/items/` | Lists items with pagination (`skip`, `limit` query params) |

**Key Logic (SQLAlchemy ORM):**
- `engine` — the database connection
- `SessionLocal` — a factory to create database sessions
- `Base.metadata.create_all()` — automatically creates the `items` table on startup if it doesn't exist
- `get_db()` — a dependency function that yields a database session and ensures it's closed after each request (safe resource management)

**Dependencies:** `fastapi`, `uvicorn`, `psycopg2-binary` (PostgreSQL driver), `sqlalchemy`, `pydantic`

#### `Dockerfile`

Unlike other services, this Dockerfile installs `libpq-dev gcc` OS packages before the Python dependencies. This is required to compile `psycopg2`, the PostgreSQL adapter.

---

### 👤 user-service

**Port:** `8003`  
**Purpose:** User registration and lookup. Stores users in **in-memory dictionary** (data is lost on restart).

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/healthz` | Returns status + total user count |
| `POST` | `/users` | Creates a new user with `{username, email}` |
| `GET` | `/users` | Lists all users |
| `GET` | `/users/{user_id}` | Fetches a specific user by ID |

**Key Detail:** Uses `pydantic.EmailStr` to validate that email addresses are correctly formatted before accepting them.  
**Dependencies:** `fastapi`, `uvicorn`, `pydantic[email]`

---

### ✅ task-service

**Port:** `8004`  
**Purpose:** Full task management (Create, Read, Update). Supports filtering tasks by `user_id`.

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/healthz` | Returns status + total task count |
| `POST` | `/tasks` | Creates a task with `{title, description, user_id}` |
| `GET` | `/tasks` | Lists all tasks, with optional `?user_id=` filter |
| `GET` | `/tasks/{task_id}` | Fetches one task |
| `PUT` | `/tasks/{task_id}` | Updates fields of an existing task (partial update) |

**Key Logic:** Uses Pydantic's `model_dump(exclude_unset=True)` for partial updates — only fields explicitly provided in the request are changed; other fields keep their current values.

---

### 🔔 notification-service

**Port:** `8005`  
**Purpose:** Queues and stores notification records. Supports filtering by `user_id`.

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/healthz` | Returns status + total queued count |
| `POST` | `/notifications` | Queues a notification with `{user_id, channel, message}` |
| `GET` | `/notifications` | Lists all notifications, with optional `?user_id=` filter |

**Channels:** `email` is the default channel; the design supports adding `sms`, `push`, etc.  
**Note:** This is a stub implementation — no real email is sent. In a production system, this would integrate with SendGrid, SNS, or a message queue like RabbitMQ.

---

### 🖥 frontend

**Port:** `8006`  
**Purpose:** Serves an HTML landing page through the API Gateway. This acts as the user-facing "homepage" of the platform.

**Key Detail:** The frontend is not a React/Vue SPA — it is a simple FastAPI route that returns a styled HTML response directly. This keep the stack simple while still demonstrating the Gateway routing pattern. The HTML includes instructions for interacting with each service's health route.

---

### 🔀 api-gateway

**Port:** `8000` (the only public-facing port in local dev)  
**Purpose:** The single entry point for all external traffic. Routes incoming requests to the correct internal service using URL **path prefixes**.

#### `main.py` — Routing Table

```
GET /             → frontend:8006 /
GET /frontend     → frontend:8006 /
ANY /auth/*       → auth-service:8001 /<path>
ANY /core/*       → core-service:8002 /<path>
ANY /users/*      → user-service:8003 /<path>
ANY /tasks/*      → task-service:8004 /<path>
ANY /notifications/* → notification-service:8005 /<path>
```

#### `proxy_request()` function

This is the core of the gateway. For every request:
1. Extracts the **body** and **headers** from the incoming request
2. Strips the `host` header (to avoid conflicts)
3. Makes an **async HTTP call** to the target service using `httpx.AsyncClient`
4. Returns the service's response back to the original caller
5. If the target service is unreachable, returns `502 Bad Gateway`

**Service URLs** are loaded from environment variables, which makes the routing configurable across Docker Compose and Kubernetes without code changes.

**Dependencies:** `fastapi`, `uvicorn`, `httpx`

---

## 📂 Folder: `/k8s`

Contains all the Kubernetes manifests that define how the application runs in a cluster. Organized by concern — not by service — to keep base infrastructure separate from application deployments.

```
k8s/
├── base/                  ← Shared namespace, configmap, and secrets
├── auth-service/          ← Deployment + Service for auth
├── user-service/          ← Deployment + Service for user
├── task-service/          ← Deployment + Service for task
├── notification-service/  ← Deployment + Service for notification
├── frontend/              ← Deployment + Service for frontend
├── database/              ← PostgreSQL Deployment, Service, PVC
├── gateway.yaml/          ← Nginx Ingress (external routing)
└── argocd/                ← Argo CD project + app definitions
```

---

### 📦 k8s/base

Shared resources that must be created **before** anything else.

#### `namespace.yaml`
Creates the `devops-app` namespace — a logical isolation boundary for all application resources.

```yaml
kind: Namespace
metadata:
  name: devops-app
  labels:
    app.kubernetes.io/part-of: multi-service-devops
```

#### `configmap.yaml`
Non-sensitive configuration shared across all services:

```yaml
data:
  DB_HOST: postgres     # Internal DNS name of the PostgreSQL service
  DB_PORT: "5432"
  DB_NAME: appdb
  APP_ENV: dev
```

A **ConfigMap** stores non-secret key-value pairs. Services reference it via `configMapKeyRef` in their Deployment specs.

#### `secrets.yaml`
Sensitive credentials. Kubernetes `Secrets` are stored as base64-encoded values (in real production, use a secrets manager like Azure Key Vault or sealed-secrets):

```yaml
stringData:
  POSTGRES_PASS: change-me            # Must be changed before production use!
  SECRET_KEY: change-me-very-long-secret  # JWT signing key for auth-service
```

---

### 🚀 k8s/auth-service

#### `deployment.yaml`
Defines how `auth-service` pods are created and maintained:

- **Replicas:** `2` (high availability — 2 pods always running)
- **Image:** `auth-service:latest` with `imagePullPolicy: IfNotPresent` (uses local image in Minikube)
- **Environment:** Injects `APP_ENV` from ConfigMap and `SECRET_KEY` from Secrets
- **Security:** `runAsNonRoot: true`, `allowPrivilegeEscalation: false` — enforced at pod level
- **Health probes:**
  - `livenessProbe`: checks `/healthz` every 10s; restarts if failing (starts checking after 20s)
  - `readinessProbe`: checks `/healthz` every 10s; stops sending traffic if failing (starts after 5s)
- **Resource limits:** max `512Mi` RAM, `500m` CPU (0.5 cores)

#### `service.yaml`
Creates an internal DNS name `auth-service` within the cluster:

```yaml
type: ClusterIP    # Internal only — NOT exposed to the internet
port: 8001         # Port other services call
targetPort: 8000   # Port the container listens on
```

`ClusterIP` means the service is only reachable from within the cluster. The pattern is the same for all other services.

---

### 🗃 k8s/database

#### `postgres-deployment.yaml`
Deploys a single PostgreSQL 16 instance:

- Credentials are pulled from the `platform-secrets` Secret and `platform-config` ConfigMap
- Mounts a **PersistentVolume** at `/var/lib/postgresql/data` so data survives pod restarts
- Uses `tcpSocket` health probes (checks the port, not an HTTP endpoint)

#### `pvc.yaml`
Requests 10Gi of persistent storage from the cluster:

```yaml
kind: PersistentVolumeClaim
spec:
  accessModes:
    - ReadWriteOnce    # Only one pod can read/write at a time (appropriate for a database)
  resources:
    requests:
      storage: 10Gi
```

The actual underlying storage (e.g., an Azure Disk) is allocated by the cluster's `StorageClass`.

---

### 🌐 k8s/gateway

#### `ingress.yaml`
The Ingress is the Kubernetes equivalent to the API Gateway for external traffic entering the cluster. It uses the **Nginx Ingress Controller** and routes by URL path:

```
devops.local/login         → auth-service:8001
devops.local/validate      → auth-service:8001
devops.local/users         → user-service:8003
devops.local/tasks         → task-service:8004
devops.local/notifications → notification-service:8005
devops.local/             → frontend:8006
```

**Note:** `devops.local` is a local hostname. To use it, you'd add an entry to `/etc/hosts` pointing to the cluster's Ingress IP.

---

### 🔄 k8s/argocd

Argo CD implements **GitOps**: the cluster state is always driven by what's in the Git repository. If you change a manifest in Git, Argo CD automatically applies the change to the cluster (self-healing).

#### `project.yaml`
Defines a security boundary for the Argo CD installation. Specifies which Git repos and which cluster namespaces this project can touch.

#### `root-application-dev.yaml`
The "App of Apps" pattern: a single Argo CD Application that points to `k8s/argocd/apps/` in the `dev` branch. When synced, it discovers all the individual app definition files in that folder and deploys them.

```yaml
source:
  repoURL: https://github.com/your-org/multi-service-devops.git
  targetRevision: dev          # Tracks the 'dev' branch
  path: k8s/argocd/apps        # Discovers all Application YAMLs here
syncPolicy:
  automated:
    prune: true                # Removes resources deleted from Git
    selfHeal: true             # Reverts manual cluster changes to match Git
```

#### `k8s/argocd/apps/` — Individual App Definitions

Each file defines one Argo CD Application. The numbering prefix controls **sync order** (sync waves):

| File | Wave | What it deploys |
|------|------|-----------------|
| `00-base.yaml` | 0 | `k8s/base` (namespace, configmap, secrets) |
| `10-database.yaml` | 10 | `k8s/database` (PostgreSQL) |
| `20-auth.yaml` | 20 | `k8s/auth-service` |
| `21-user.yaml` | 21 | `k8s/user-service` |
| `22-task.yaml` | 22 | `k8s/task-service` |
| `23-notification.yaml` | 23 | `k8s/notification-service` |
| `24-frontend.yaml` | 24 | `k8s/frontend` |
| `30-ingress.yaml` | 30 | `k8s/gateway.yaml` (Ingress) |

This guarantees the namespace and database are ready **before** the application services are deployed.

---

## 📂 Folder: `/ansible`

Ansible is used to **prepare virtual machines** so they are ready to run the platform. It does not deploy the application itself — that is handled by Kubernetes. Ansible's job is OS-level setup.

```
ansible/
├── ansible.cfg          ← Ansible configuration (SSH, inventory path)
├── inventory/
│   └── dev/
│       └── hosts.ini    ← IP addresses of target VMs
├── playbooks/
│   ├── site.yml         ← Master playbook (imports all others)
│   └── tooling.yml      ← Configures the tooling VM
└── roles/
    ├── common/          ← Base OS packages
    ├── docker/          ← Docker installation
    └── tooling/         ← DevOps tools (kubectl, Helm, Terraform, Azure CLI)
```

### `ansible.cfg`

```ini
[defaults]
inventory = inventory/dev/hosts.ini   # Default inventory file
host_key_checking = False             # Skip SSH host fingerprint confirmation (convenience)
interpreter_python = auto_silent      # Auto-detect Python without warnings

[ssh_connection]
pipelining = True                     # Speeds up execution by reusing SSH connections
```

### `inventory/dev/hosts.ini`

```ini
[tooling]
tooling-vm ansible_host=172.161.10.187    # Public IP of the "tooling" VM (output by Terraform)

[appdb]
appdb-vm ansible_host=51.107.72.128      # Public IP of the "appdb" VM (output by Terraform)

[all:vars]
ansible_user=azureuser                   # SSH user (matches Terraform VM config)
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

The IPs in this file are generated by Terraform. The comment tells you to use `terraform output` to get the current values.

### `playbooks/site.yml`
The master playbook. Running `ansible-playbook playbooks/site.yml` runs everything:
```yaml
- import_playbook: tooling.yml   # Configures the tooling VM
- import_playbook: appdb.yml     # Configures the database VM
```

### `roles/common/tasks/main.yml`
Installs essential OS packages on any VM:
`curl`, `git`, `unzip`, `jq`, `ca-certificates`, `gnupg`, `lsb-release`, `apt-transport-https`, `software-properties-common`

### `roles/docker/tasks/main.yml`
Installs Docker Engine from the official Docker apt repository:
1. Installs prerequisites
2. Adds Docker's GPG key and apt repository
3. Installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose-plugin`
4. Enables and starts the `docker` systemd service
5. Adds the Ansible SSH user to the `docker` group (so Docker commands work without `sudo`)

### `roles/tooling/tasks/main.yml`
Installs the full DevOps toolchain on the "tooling" VM:
- `kubectl` (v1.30.0) — Kubernetes command-line tool
- `helm` — Kubernetes package manager (auto-install script)
- `terraform` — Infrastructure as Code tool (via HashiCorp apt repo)
- `azure-cli` — Azure cloud management tool

---

## 📂 Folder: `/terraform`

Terraform provisions the **cloud infrastructure** on **Microsoft Azure** that the application runs on. It creates the network, Kubernetes cluster, VMs, and monitoring infrastructure.

```
terraform/
├── modules/           ← Reusable infrastructure building blocks
│   ├── network/       ← Azure Virtual Network + subnets
│   ├── k8s-cluster/   ← Azure Kubernetes Service (AKS)
│   ├── vm-infra/      ← Two Linux VMs (tooling + appdb)
│   └── monitoring/    ← Azure Log Analytics + Application Insights
└── envs/
    └── dev/           ← Dev environment (wires modules together)
        ├── main.tf          ← Module composition
        ├── variables.tf     ← Input variable declarations
        ├── terraform.tfvars ← Actual values for the dev environment
        ├── outputs.tf       ← Exported values (e.g., VM IPs)
        └── versions.tf      ← Required Terraform/provider versions
```

### Module: `network`

Creates the Azure Virtual Network and all subnets dynamically using `for_each`:

```hcl
resource "azurerm_resource_group" "network" { ... }
resource "azurerm_virtual_network" "network" {
  address_space = [var.vpc_cidr]   # e.g., "10.10.0.0/16"
}
resource "azurerm_subnet" "public" {   # Two public subnets
  for_each = local.public_subnets
}
resource "azurerm_subnet" "private" {  # Two private subnets
  for_each = local.private_subnets
}
```

### Module: `k8s-cluster`

Provisions an **Azure Kubernetes Service (AKS)** cluster:

```hcl
resource "azurerm_kubernetes_cluster" "cluster" {
  kubernetes_version  = var.kubernetes_version    # e.g., "1.34.3"
  default_node_pool {
    node_count = var.node_count                   # How many nodes (VMs) in the cluster
    vm_size    = var.node_instance_type           # e.g., "Standard_B2s_v2"
    vnet_subnet_id = var.private_subnet_ids[0]   # Placed in private subnet
  }
  identity { type = "SystemAssigned" }           # Managed Identity (no manual credentials)
  network_profile {
    network_plugin = "azure"                     # Azure CNI for pod networking
    network_policy = "azure"                     # Network policies for pod isolation
  }
}
```

### Module: `vm-infra`

Creates two Linux virtual machines on **Ubuntu 22.04**:

| VM | Purpose |
|----|---------|
| `tooling` | A bastion/operator VM with kubectl, Helm, Terraform, az CLI installed by Ansible |
| `appdb` | A VM intended for database-related operations |

Both VMs use **SSH key authentication** (no passwords) and are protected by a Network Security Group (NSG) that allows SSH (22), HTTP (80), and HTTPS (443).

### Module: `monitoring`

Provisions Azure-native observability:
- **Azure Log Analytics Workspace** — collects logs from AKS
- **Azure Application Insights** — application performance monitoring (created only if `enable_grafana = true`)

### `envs/dev/terraform.tfvars` — Actual Values

```hcl
project_name        = "multi-service-devops"
environment         = "dev"
resource_group_name = "rg-multi-service-dev"
region              = "switzerlandnorth"         # Target Azure region

vpc_cidr            = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]

kubernetes_version  = "1.34.3"
node_count          = 1
node_instance_type  = "Standard_B2s_v2"

enable_prometheus   = true
enable_grafana      = true
tooling_vm_size     = "Standard_D2s_v3"
appdb_vm_size       = "Standard_D2s_v3"
```

---

## ⚙️ CI/CD: GitHub Actions

**File:** `.github/workflows/ci.yml`  
**Trigger:** Every push to `main` or `dev`, plus every pull request

### Pipeline Stages

```
┌──────────────────────────────┐
│         validate             │
│  1. Python syntax check      │
│  2. Terraform validate (dev) │
│  3. YAML lint (yamllint)     │
└──────────┬───────────────────┘
           │ (must pass first)
┌──────────▼───────────────────┐
│       build-images           │
│  Builds Docker image for:    │
│  - auth-service              │
│  - core-service              │
│  - api-gateway               │
│  - user-service              │
│  - task-service              │
│  - notification-service      │
│  - frontend                  │
└──────────────────────────────┘
```

**Job: `validate`**
- Python syntax with `python -m compileall services` — catches syntax errors before building images
- Terraform `init -backend=false` + `validate` — validates HCL syntax without connecting to Azure
- `yamllint` — enforces consistent YAML formatting across `k8s/`, `ansible/`, `docker-compose.yml`

**Job: `build-images`**
- Runs only after `validate` succeeds (`needs: validate`)
- Builds each Docker image to catch `Dockerfile` or dependency resolution errors early

---

## 📄 Root-Level Files

### `docker-compose.yml`

The local development orchestrator. Runs the complete platform on a single machine with one command:

```bash
docker-compose up -d
```

**Services and their local ports:**

| Service | Internal Port | Exposed Port |
|---------|--------------|--------------|
| postgres | 5432 | 5432 |
| auth-service | 8000 | 8001 |
| core-service | 8000 | 8002 |
| user-service | 8000 | 8003 |
| task-service | 8000 | 8004 |
| notification-service | 8000 | 8005 |
| frontend | 8000 | 8006 |
| api-gateway | 8000 | **8000** ← the main entry point |

**Key configuration:**
- `core-service` uses `depends_on` with `condition: service_healthy` — it waits until PostgreSQL passes its health check before starting. This prevents connection errors on startup.
- `postgres` has a `healthcheck` using `pg_isready` to signal when it's truly ready
- A named volume `postgres_data` keeps database data persistent between `docker-compose down/up` cycles

### `.gitignore`

Prevents committing:
- Python: `__pycache__/`, `*.pyc`, `.venv/`
- Terraform: `.terraform/`, `terraform.tfstate` (state files must not be in Git)
- General: `.env` files, IDE configs

---

## ⚙️ Tools & Technologies

| Tool | Role in Project | How Configured |
|------|----------------|----------------|
| **FastAPI** | HTTP framework for all microservices | `main.py` — `app = FastAPI(...)` |
| **Uvicorn** | ASGI server that runs FastAPI apps | CMD in Dockerfile + port 8000 |
| **Pydantic** | Data validation / serialization schemas | `class XModel(BaseModel)` in each service |
| **PyJWT** | JWT token creation/validation | Used in `auth-service` only |
| **SQLAlchemy** | ORM for database operations | Used in `core-service` with PostgreSQL |
| **httpx** | Async HTTP client for proxying requests | Used in `api-gateway` |
| **PostgreSQL 16** | Relational database for `core-service` | Docker image `postgres:16-alpine` |
| **Docker** | Containerizes each service | `Dockerfile` in every service folder |
| **Docker Compose** | Local multi-container orchestration | `docker-compose.yml` at root |
| **Kubernetes** | Production container orchestration | All files in `k8s/` |
| **Argo CD** | GitOps continuous delivery operator | `k8s/argocd/` |
| **Terraform** | Cloud infrastructure provisioning (IaC) | `terraform/` |
| **Ansible** | VM configuration management | `ansible/` |
| **GitHub Actions** | CI pipeline (validate + build) | `.github/workflows/ci.yml` |
| **Azure (AKS)** | Target cloud for production deployment | Terraform `azurerm` provider |
| **Nginx Ingress** | External Kubernetes traffic routing | `k8s/gateway.yaml/ingress.yaml` |

---

## 🔑 Configuration Keys Reference

### Docker Compose Environment Variables

| Key | Service | Description | Example |
|-----|---------|-------------|---------|
| `SECRET_KEY` | auth-service | JWT signing secret. Must be long and random in production. | `change-me-very-long-secret` |
| `APP_ENV` | all | Deployment environment tag | `dev` |
| `DATABASE_URL` | core-service | Full SQLAlchemy database connection string | `postgresql+psycopg2://postgres:change-me@postgres:5432/appdb` |
| `POSTGRES_DB` | postgres | Database name to create on startup | `appdb` |
| `POSTGRES_USER` | postgres | Super-user name | `postgres` |
| `POSTGRES_PASSWORD` | postgres | Super-user password | `change-me` |
| `AUTH_SERVICE_URL` | api-gateway | Internal URL of auth-service | `http://auth-service:8000` |
| `CORE_SERVICE_URL` | api-gateway | Internal URL of core-service | `http://core-service:8000` |
| `USER_SERVICE_URL` | api-gateway | Internal URL of user-service | `http://user-service:8000` |
| `TASK_SERVICE_URL` | api-gateway | Internal URL of task-service | `http://task-service:8000` |
| `NOTIFICATION_SERVICE_URL` | api-gateway | Internal URL of notification-service | `http://notification-service:8000` |
| `FRONTEND_SERVICE_URL` | api-gateway | Internal URL of frontend | `http://frontend:8000` |

### Kubernetes ConfigMap (`platform-config`)

| Key | Description | Value |
|-----|-------------|-------|
| `DB_HOST` | PostgreSQL service DNS name inside cluster | `postgres` |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_NAME` | Application database name | `appdb` |
| `APP_ENV` | Environment label | `dev` |

### Kubernetes Secret (`platform-secrets`)

| Key | Description | ⚠️ Production Action |
|-----|-------------|---------------------|
| `POSTGRES_PASS` | PostgreSQL password | Replace with a strong random password |
| `SECRET_KEY` | JWT signing key for auth-service | Replace with a 256-bit cryptographically random string |

### Terraform Variables (`terraform.tfvars`)

| Variable | Description | Dev Value |
|----------|-------------|-----------|
| `project_name` | Tag applied to all resources | `multi-service-devops` |
| `environment` | Environment name | `dev` |
| `resource_group_name` | Azure Resource Group | `rg-multi-service-dev` |
| `region` | Azure region for all resources | `switzerlandnorth` |
| `vpc_cidr` | VNet IP range | `10.10.0.0/16` |
| `public_subnet_cidrs` | Public subnet ranges | `["10.10.1.0/24", "10.10.2.0/24"]` |
| `private_subnet_cidrs` | Private subnet ranges | `["10.10.11.0/24", "10.10.12.0/24"]` |
| `kubernetes_version` | AKS Kubernetes version | `1.34.3` |
| `node_count` | AKS node pool size | `1` |
| `node_instance_type` | AKS node VM size | `Standard_B2s_v2` |
| `tooling_vm_size` | Size of tooling VM | `Standard_D2s_v3` |
| `appdb_vm_size` | Size of appdb VM | `Standard_D2s_v3` |
| `admin_username` | SSH username for VMs | `azureuser` |
| `admin_ssh_public_key` | SSH public key for VM access | Your `~/.ssh/id_rsa.pub` |
| `allowed_ssh_cidr` | IP range allowed to SSH | `0.0.0.0/0` (restrict in prod!) |
| `enable_prometheus` | Enable Prometheus monitoring | `true` |
| `enable_grafana` | Enable Grafana / App Insights | `true` |

---

## 🚀 Request Flow Walkthrough

### Example: A user logs in and gets their tasks

```
1. Browser (or API client)
   └─► POST http://localhost:8000/auth/login
       Body: {"username": "admin", "password": "admin123"}

2. api-gateway (port 8000)
   └─► Receives request, matches route /auth/{path}
   └─► proxy_request() → POST http://auth-service:8000/login

3. auth-service (port 8001)
   └─► Validates credentials (admin/admin123 ✓)
   └─► Creates JWT: {"sub": "admin", "exp": <1 hour from now>}
   └─► Signs with SECRET_KEY using HS256
   └─► Returns {"access_token": "<jwt>", "type": "bearer"}

4. api-gateway
   └─► Forwards response back to browser

5. Browser
   └─► GET http://localhost:8000/tasks?user_id=1
       Header: Authorization: Bearer <jwt>

6. api-gateway
   └─► Matches route /tasks/{path}
   └─► proxy_request() → GET http://task-service:8000/tasks?user_id=1

7. task-service (port 8004)
   └─► Filters tasks where task.user_id == 1
   └─► Returns [{"id":1, "title":"...", "user_id":1, "completed":false}, ...]

8. api-gateway → Browser ✓
```

### Local Development vs Kubernetes

| Concern | Docker Compose (Local) | Kubernetes (Production) |
|---------|----------------------|------------------------|
| Service discovery | Docker DNS (`auth-service`, `postgres`) | K8s ClusterIP Services + CoreDNS |
| Secrets | Environment variables in compose file | K8s `Secret` resources |
| Config | Environment variables in compose file | K8s `ConfigMap` resources |
| Persistence | Named Docker volume | PersistentVolumeClaim (Azure Disk) |
| External routing | Port mapping (`8000:8000`) | Nginx Ingress Controller |
| Deployment mgmt | Manual (`docker-compose up`) | Argo CD GitOps (automated) |
| Infrastructure | Local machine | Azure (AKS + VMs via Terraform) |
| Health checks | `healthcheck:` in compose file | `livenessProbe` + `readinessProbe` |

---

> 📌 **This documentation was auto-generated by analyzing all files and folders in the `multi-service-devops` repository.**  
> Last updated: March 2026
