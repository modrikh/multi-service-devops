#!/usr/bin/env bash
# =============================================================================
#  build.sh — Build, tag, push all service images to ACR and patch k8s manifests
#
#  What it does:
#    1. Reads ACR login server from Terraform output (auto-detected)
#    2. Logs in to ACR via Azure CLI
#    3. Builds each service Docker image in parallel
#    4. Tags and pushes all images to ACR
#    5. Patches all k8s deployment.yaml files with the full ACR image path
#
#  Usage:
#    ./build.sh                       # Build all services (tag: latest)
#    ./build.sh --tag v1.2.3          # Build with a specific tag
#    ./build.sh --env dev             # Explicit environment (default: dev)
#    ./build.sh --services "auth-service user-service"  # Build specific services only
#    ./build.sh --skip-push           # Build only, do not push
#    ./build.sh --skip-patch          # Don't update k8s manifests after push
#    ./build.sh --help                # Show this help
# =============================================================================

set -euo pipefail

# ─── Colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Defaults ────────────────────────────────────────────────────────────────
ENV="dev"
TAG="latest"
SKIP_PUSH=false
SKIP_PATCH=false
CUSTOM_SERVICES=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/terraform/envs/${ENV}"
K8S_DIR="${SCRIPT_DIR}/k8s"
SERVICES_DIR="${SCRIPT_DIR}/services"

# All buildable services (maps service name → services/ subfolder name)
declare -A SERVICE_MAP=(
  [auth-service]="auth-service"
  [core-service]="core-service"
  [user-service]="user-service"
  [task-service]="task-service"
  [notification-service]="notification-service"
  [frontend]="frontend"
  [api-gateway]="api-gateway"
)

# ─── Helpers ─────────────────────────────────────────────────────────────────
log()     { echo -e "${BOLD}${CYAN}[build]${RESET} $*"; }
success() { echo -e "${BOLD}${GREEN}[✔]${RESET} $*"; }
warn()    { echo -e "${BOLD}${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${BOLD}${RED}[✖]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

print_banner() {
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║      multi-service-devops  ·  build.sh       ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

usage() {
  grep '^#  ' "$0" | sed 's/^#  //'
  exit 0
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)       ENV="$2"; shift 2 ;;
    --tag)       TAG="$2"; shift 2 ;;
    --services)  CUSTOM_SERVICES="$2"; shift 2 ;;
    --skip-push)  SKIP_PUSH=true; shift ;;
    --skip-patch) SKIP_PATCH=true; shift ;;
    --help|-h)   usage ;;
    *) die "Unknown option: $1. Run with --help for usage." ;;
  esac
done

# Rebuild path if --env was passed
TF_DIR="${SCRIPT_DIR}/terraform/envs/${ENV}"

# Build the list of services to process
if [[ -n "${CUSTOM_SERVICES}" ]]; then
  IFS=' ' read -ra SERVICES <<< "${CUSTOM_SERVICES}"
else
  SERVICES=("${!SERVICE_MAP[@]}")
fi

# ─── Dependency checks ────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  command -v docker &>/dev/null || missing+=("docker")
  command -v az     &>/dev/null || missing+=("az (Azure CLI)")
  command -v terraform &>/dev/null || missing+=("terraform")
  command -v jq     &>/dev/null || missing+=("jq")

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required tools: ${missing[*]}"
  fi
  success "All required tools found"
}

# ─── Get ACR login server from Terraform ─────────────────────────────────────
get_acr_server() {
  log "Reading ACR login server from Terraform outputs..."
  [[ -d "${TF_DIR}" ]] || die "Terraform env directory not found: ${TF_DIR}"

  pushd "${TF_DIR}" > /dev/null
  ACR_SERVER=$(terraform output -json 2>/dev/null | jq -r '.acr_login_server.value // empty')
  popd > /dev/null

  if [[ -z "${ACR_SERVER}" ]]; then
    die "Could not read 'acr_login_server' from Terraform output.\n       Run 'terraform apply' first, or pass --acr <server> manually."
  fi

  success "ACR login server: ${ACR_SERVER}"
}

# ─── ACR login via Azure CLI ──────────────────────────────────────────────────
acr_login() {
  log "Logging in to ACR: ${ACR_SERVER}"
  az acr login --name "${ACR_SERVER%%.*}"  # strip .azurecr.io suffix for az acr login
  success "ACR login successful"
}

# ─── Build one image ──────────────────────────────────────────────────────────
build_image() {
  local svc="$1"
  local folder="${SERVICE_MAP[$svc]}"
  local context="${SERVICES_DIR}/${folder}"
  local local_tag="${svc}:${TAG}"
  local remote_tag="${ACR_SERVER}/${svc}:${TAG}"

  if [[ ! -d "${context}" ]]; then
    warn "Skipping ${svc}: directory '${context}' not found"
    return 0
  fi

  echo -e "${BOLD}  ── Building ${svc}${RESET}"
  docker build \
    --tag "${local_tag}" \
    --tag "${remote_tag}" \
    --file "${context}/Dockerfile" \
    "${context}" \
    2>&1 | sed "s/^/    [${svc}] /"

  echo "" # spacing
}

# ─── Push one image ───────────────────────────────────────────────────────────
push_image() {
  local svc="$1"
  local remote_tag="${ACR_SERVER}/${svc}:${TAG}"

  echo -e "${BOLD}  ── Pushing ${svc} → ${remote_tag}${RESET}"
  docker push "${remote_tag}" 2>&1 | sed "s/^/    [${svc}] /"
  success "Pushed: ${remote_tag}"
}

# ─── Patch k8s deployment.yaml ────────────────────────────────────────────────
patch_manifests() {
  log "Patching k8s deployment manifests with ACR image paths..."

  for svc in "${SERVICES[@]}"; do
    local deploy_file="${K8S_DIR}/${svc}/deployment.yaml"

    if [[ ! -f "${deploy_file}" ]]; then
      # api-gateway might be under a different path
      deploy_file="${K8S_DIR}/gateway.yaml/deployment.yaml"
      [[ -f "${deploy_file}" ]] || continue
    fi

    local old_image="${svc}:latest"
    local new_image="${ACR_SERVER}/${svc}:${TAG}"

    # Only patch if the image line doesn't already contain the ACR server
    if grep -q "image: ${ACR_SERVER}" "${deploy_file}" 2>/dev/null; then
      warn "  ${svc}: already pointing to ACR — skipping patch"
      continue
    fi

    # Replace the bare image name with the full ACR path
    sed -i "s|image: ${svc}:.*|image: ${new_image}|g" "${deploy_file}"
    success "  Patched ${deploy_file##*/k8s/} → ${new_image}"
  done

  log "All manifests updated. Apply with: kubectl apply -R -f k8s/"
}

# ─── Build all in parallel ────────────────────────────────────────────────────
build_all_parallel() {
  log "Building ${#SERVICES[@]} service(s) in parallel..."
  echo ""

  local pids=()
  local failed=()

  for svc in "${SERVICES[@]}"; do
    build_image "${svc}" &
    pids+=("$!:${svc}")
  done

  # Wait for all builds and collect failures
  for entry in "${pids[@]}"; do
    local pid="${entry%%:*}"
    local svc="${entry##*:}"
    if ! wait "${pid}"; then
      failed+=("${svc}")
      error "Build FAILED for: ${svc}"
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    die "The following builds failed: ${failed[*]}"
  fi

  success "All images built successfully"
}

# ─── Push all sequentially (avoids layer conflicts on parallel push) ───────────
push_all() {
  log "Pushing ${#SERVICES[@]} image(s) to ${ACR_SERVER}..."
  echo ""

  for svc in "${SERVICES[@]}"; do
    if [[ -z "${SERVICE_MAP[$svc]+_}" ]]; then
      warn "Unknown service '${svc}' — skipping"
      continue
    fi
    push_image "${svc}"
  done

  success "All images pushed to ACR"
}

# ─── Summary ─────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}${GREEN}  Build complete!${RESET}"
  echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${RESET}"
  echo ""
  echo -e "  Registry   : ${BOLD}${ACR_SERVER}${RESET}"
  echo -e "  Tag        : ${BOLD}${TAG}${RESET}"
  echo -e "  Services   : ${BOLD}${SERVICES[*]}${RESET}"
  echo ""
  echo -e "  ${YELLOW}Next steps:${RESET}"
  echo -e "    kubectl apply -f k8s/base"
  echo -e "    kubectl apply -f k8s/database"
  echo -e "    kubectl apply -R -f k8s/"
  echo -e "    kubectl get pods -n devops-app"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  print_banner
  log "Environment : ${ENV}"
  log "Tag         : ${TAG}"
  log "Services    : ${SERVICES[*]}"
  log "Push        : $(if "${SKIP_PUSH}"; then echo SKIPPED; else echo ENABLED; fi)"
  log "Patch k8s   : $(if "${SKIP_PATCH}"; then echo SKIPPED; else echo ENABLED; fi)"
  echo ""

  check_deps
  get_acr_server
  acr_login

  echo ""
  log "━━━ Step 1/3 — Build images (parallel) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  build_all_parallel

  if "${SKIP_PUSH}"; then
    warn "Skipping push (--skip-push flag set)"
  else
    echo ""
    log "━━━ Step 2/3 — Push images to ACR (sequential) ━━━━━━━━━━━━━━━━━━━━━━"
    push_all
  fi

  if "${SKIP_PATCH}"; then
    warn "Skipping k8s manifest patch (--skip-patch flag set)"
  else
    echo ""
    log "━━━ Step 3/3 — Patch k8s deployment manifests ━━━━━━━━━━━━━━━━━━━━━━━"
    patch_manifests
  fi

  print_summary
}

main
