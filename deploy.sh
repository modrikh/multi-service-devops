#!/usr/bin/env bash
# =============================================================================
#  deploy.sh — Full infrastructure + configuration deploy
#
#  Steps:
#    1. Run terraform init + apply (terraform/envs/dev)
#    2. Extract tooling_public_ip + appdb_public_ip from Terraform outputs
#    3. Patch ansible/inventory/dev/hosts.ini with the real IPs
#    4. Run ansible-playbook playbooks/site.yml
#
#  Usage:
#    ./deploy.sh                    # Full deploy (default: dev)
#    ./deploy.sh --env dev          # Explicit environment
#    ./deploy.sh --skip-terraform   # Skip Terraform, only update IPs + run Ansible
#    ./deploy.sh --skip-ansible     # Only provision infra, skip Ansible
#    ./deploy.sh --plan-only        # Only run terraform plan, do not apply
#    ./deploy.sh --help             # Show this help
# =========================================================git====================

set -euo pipefail

# ─── Colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Defaults ───────────────────────────────────────────────────────────────
ENV="dev"
SKIP_TERRAFORM=false
SKIP_ANSIBLE=false
PLAN_ONLY=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/terraform/envs/${ENV}"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
HOSTS_FILE="${ANSIBLE_DIR}/inventory/${ENV}/hosts.ini"

# ─── Helpers ────────────────────────────────────────────────────────────────
log()     { echo -e "${BOLD}${CYAN}[deploy]${RESET} $*"; }
success() { echo -e "${BOLD}${GREEN}[✔]${RESET} $*"; }
warn()    { echo -e "${BOLD}${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${BOLD}${RED}[✖]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

print_banner() {
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║      multi-service-devops  ·  deploy.sh      ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

usage() {
  grep '^#  ' "$0" | sed 's/^#  //'
  exit 0
}

# ─── Argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)            ENV="$2"; shift 2 ;;
    --skip-terraform) SKIP_TERRAFORM=true; shift ;;
    --skip-ansible)   SKIP_ANSIBLE=true; shift ;;
    --plan-only)      PLAN_ONLY=true; shift ;;
    --help|-h)        usage ;;
    *) die "Unknown option: $1. Run with --help for usage." ;;
  esac
done

# Recalculate paths after --env is parsed
TF_DIR="${SCRIPT_DIR}/terraform/envs/${ENV}"
HOSTS_FILE="${ANSIBLE_DIR}/inventory/${ENV}/hosts.ini"

# ─── Dependency checks ───────────────────────────────────────────────────────
check_deps() {
  local missing=()
  command -v terraform  &>/dev/null || missing+=("terraform")
  command -v ansible-playbook &>/dev/null || missing+=("ansible-playbook")
  command -v jq          &>/dev/null || missing+=("jq")

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required tools: ${missing[*]}\nInstall them and try again."
  fi
  success "All required tools found (terraform, ansible-playbook, jq)"
}

# ─── Terraform ───────────────────────────────────────────────────────────────
run_terraform() {
  log "Terraform directory: ${TF_DIR}"
  [[ -d "${TF_DIR}" ]] || die "Terraform env directory not found: ${TF_DIR}"

  pushd "${TF_DIR}" > /dev/null

  log "Running: terraform init"
  terraform init -upgrade

  if "${PLAN_ONLY}"; then
    log "Running: terraform plan (--plan-only mode, will not apply)"
    terraform plan -var-file="terraform.tfvars"
    warn "Plan-only mode — no resources were created."
    popd > /dev/null
    exit 0
  fi

  log "Running: terraform apply"
  terraform apply -var-file="terraform.tfvars" -auto-approve

  success "Terraform apply completed"
  popd > /dev/null
}

# ─── Extract Terraform outputs ───────────────────────────────────────────────
get_tf_outputs() {
  log "Extracting VM IPs from Terraform outputs..."
  pushd "${TF_DIR}" > /dev/null

  # Capture the full JSON output object once
  local tf_output
  tf_output=$(terraform output -json)

  TOOLING_IP=$(echo "${tf_output}" | jq -r '.tooling_public_ip.value // empty')
  APPDB_IP=$(echo "${tf_output}"   | jq -r '.appdb_public_ip.value  // empty')

  popd > /dev/null

  [[ -n "${TOOLING_IP}" ]] || die "Could not read 'tooling_public_ip' from Terraform output. Has the infrastructure been applied?"
  [[ -n "${APPDB_IP}"   ]] || die "Could not read 'appdb_public_ip' from Terraform output."

  success "tooling_public_ip = ${TOOLING_IP}"
  success "appdb_public_ip   = ${APPDB_IP}"
}

# ─── Patch hosts.ini ─────────────────────────────────────────────────────────
patch_hosts_ini() {
  log "Patching inventory file: ${HOSTS_FILE}"
  [[ -f "${HOSTS_FILE}" ]] || die "Inventory file not found: ${HOSTS_FILE}"

  # Back up the original file (timestamped)
  local backup="${HOSTS_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
  cp "${HOSTS_FILE}" "${backup}"
  log "Backup saved → ${backup}"

  # Replace the IP on the line that contains 'tooling-vm ansible_host='
  sed -i "s/^\(tooling-vm ansible_host=\)[^ ]*/\1${TOOLING_IP}/" "${HOSTS_FILE}"

  # Replace the IP on the line that contains 'appdb-vm ansible_host='
  sed -i "s/^\(appdb-vm ansible_host=\)[^ ]*/\1${APPDB_IP}/" "${HOSTS_FILE}"

  success "hosts.ini updated:"
  grep -E 'ansible_host=' "${HOSTS_FILE}" | sed 's/^/    /'
}

# ─── Ansible ─────────────────────────────────────────────────────────────────
run_ansible() {
  log "Ansible directory: ${ANSIBLE_DIR}"
  [[ -d "${ANSIBLE_DIR}" ]] || die "Ansible directory not found: ${ANSIBLE_DIR}"

  pushd "${ANSIBLE_DIR}" > /dev/null

  log "Waiting 30 seconds for VMs to finish booting..."
  sleep 30

  log "Running: ansible-playbook playbooks/site.yml"
  ansible-playbook playbooks/site.yml

  success "Ansible playbook completed"
  popd > /dev/null
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  print_banner
  log "Environment : ${ENV}"
  log "Terraform   : $(if "${SKIP_TERRAFORM}"; then echo SKIPPED; else echo ENABLED; fi)"
  log "Ansible     : $(if "${SKIP_ANSIBLE}";   then echo SKIPPED; else echo ENABLED; fi)"
  echo ""

  check_deps

  # ── Step 1: Terraform ────────────────────────────────────────────────────
  if "${SKIP_TERRAFORM}"; then
    warn "Skipping Terraform (--skip-terraform flag set)"
  else
    log "━━━ Step 1/3 — Terraform apply ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    run_terraform
  fi

  # ── Step 2: Get IPs + patch hosts.ini ────────────────────────────────────
  log "━━━ Step 2/3 — Update inventory IPs ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  get_tf_outputs
  patch_hosts_ini

  # ── Step 3: Ansible ──────────────────────────────────────────────────────
  if "${SKIP_ANSIBLE}"; then
    warn "Skipping Ansible (--skip-ansible flag set)"
  else
    log "━━━ Step 3/3 — Ansible playbooks ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    run_ansible
  fi

  echo ""
  success "All done! ✨"
  echo -e "  Tooling VM IP : ${BOLD}${TOOLING_IP}${RESET}"
  echo -e "  AppDB VM IP   : ${BOLD}${APPDB_IP}${RESET}"
}

main
