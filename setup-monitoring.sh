#!/usr/bin/env bash
# =============================================================================
#  setup-monitoring.sh — Full Observability Stack (Metrics, Logs, Traces)
#
#  Installs the industry-best-practice Grafana LGTM stack for Kubernetes:
#    1. kube-prometheus-stack (Prometheus metrics & Grafana UI)
#    2. Loki (Centralized logging)
#    3. Promtail (Log shipping agent for all pods)
#    4. Tempo (Distributed tracing)
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

NAMESPACE="observability"

log()     { echo -e "${BOLD}${CYAN}[monitoring]${RESET} $*"; }
success() { echo -e "${BOLD}${GREEN}[✔]${RESET} $*"; }
warn()    { echo -e "${BOLD}${YELLOW}[!]${RESET} $*"; }

# ─── Add Helm Repositories ───────────────────────────────────────────────────
log "Adding required Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update > /dev/null
success "Helm repositories updated"

# ─── Create Namespace ────────────────────────────────────────────────────────
log "Ensuring namespace '${NAMESPACE}' exists..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
success "Namespace created"

# ─── 1. Prometheus & Grafana (Metrics & Dashboards) ─────────────────────────
log "Deploying kube-prometheus-stack (Metrics)..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --set grafana.adminPassword="admin" \
  --set grafana.sidecar.datasources.defaultDatasourceEnabled=true \
  --wait --timeout 10m
success "Prometheus & Grafana deployed"

# ─── 2. Loki (Log Storage) ───────────────────────────────────────────────────
log "Deploying Loki (Log Storage)..."
helm upgrade --install loki grafana/loki \
  --namespace "${NAMESPACE}" \
  --set deploymentMode=SingleBinary \
  --set loki.auth_enabled=false \
  --set loki.commonConfig.replication_factor=1 \
  --set singleBinary.replicas=1 \
  --wait --timeout 10m
success "Loki deployed"

# ─── 3. Promtail (Log Collector) ─────────────────────────────────────────────
log "Deploying Promtail (Log Collector)..."
helm upgrade --install promtail grafana/promtail \
  --namespace "${NAMESPACE}" \
  --set "config.clients[0].url=http://loki.${NAMESPACE}.svc.cluster.local:3100/loki/api/v1/push" \
  --wait --timeout 5m
success "Promtail deployed and connected to Loki"

# ─── 4. Tempo (Distributed Tracing) ──────────────────────────────────────────
log "Deploying Tempo (Distributed Tracing)..."
helm upgrade --install tempo grafana/tempo \
  --namespace "${NAMESPACE}" \
  --wait --timeout 10m
success "Tempo deployed"

# ─── Summary & Access Instructions ───────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Observability Stack Successfully Deployed!   ${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${RESET}"
echo ""
echo "This stack includes the 'holy trinity' of observability:"
echo "  📊 Metrics : Prometheus"
echo "  📝 Logs    : Loki + Promtail"
echo "  🕸️ Traces  : Tempo"
echo "  🎨 UI      : Grafana"
echo ""
echo -e "${BOLD}To access Grafana and view everything:${RESET}"
echo "  1. Run this command in a terminal:"
echo "     kubectl port-forward svc/prometheus-grafana -n ${NAMESPACE} 3000:80"
echo "  2. Open http://localhost:3000 in your browser"
echo "  3. Login with:"
echo "       Username: admin"
echo "       Password: admin"
echo ""
echo -e "${BOLD}Next step in Grafana:${RESET}"
echo "You need to add Loki and Tempo as Data Sources inside Grafana UI:"
echo "  - Loki URL : http://loki.${NAMESPACE}.svc.cluster.local:3100"
echo "  - Tempo URL: http://tempo.${NAMESPACE}.svc.cluster.local:3100"
