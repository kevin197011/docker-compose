#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_requirements() {
  command -v docker >/dev/null || { log_error "Docker is required"; exit 1; }
  docker compose version >/dev/null || { log_error "Docker Compose v2 is required"; exit 1; }
  command -v openssl >/dev/null || { log_error "openssl is required to generate passwords"; exit 1; }
  log_success "Dependencies OK"
}

gen_password() {
  openssl rand -hex 16
}

ensure_env() {
  if [[ -f .env ]]; then
    return
  fi

  [[ -f .env.example ]] || { log_error ".env.example not found"; exit 1; }

  local root_pass pg_pass redis_pass
  root_pass=$(gen_password)
  pg_pass=$(gen_password)
  redis_pass=$(gen_password)

  sed \
    -e "s/^GITLAB_ROOT_PASSWORD=.*/GITLAB_ROOT_PASSWORD=${root_pass}/" \
    -e "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${pg_pass}/" \
    -e "s/^GITLAB_REDIS_PASSWORD=.*/GITLAB_REDIS_PASSWORD=${redis_pass}/" \
    .env.example > .env

  mkdir -p data
  cat > data/.credentials <<EOF
# Generated $(date -Iseconds) — keep secret, do not commit
GITLAB_ROOT_PASSWORD=${root_pass}
POSTGRES_PASSWORD=${pg_pass}
GITLAB_REDIS_PASSWORD=${redis_pass}
EOF
  chmod 600 data/.credentials .env

  log_success "Generated .env with random passwords (also saved to data/.credentials)"
  echo
  echo "  GitLab root:  ${root_pass}"
  echo "  PostgreSQL:   ${pg_pass}"
  echo "  Redis:        ${redis_pass}"
  echo
  log_warn "Save these passwords — they are not shown again unless you read data/.credentials"
}

create_directories() {
  mkdir -p \
    data/postgresql \
    data/redis-cache \
    data/redis-persistent \
    data/redis-sessions \
    data/gitlab/config \
    data/gitlab/log \
    data/gitlab/data \
    data/gitlab/backups \
    data/gitlab-runner/config
  chmod +x bootstrap.sh register-runner.sh ci-smoke-test.sh 2>/dev/null || true
  log_success "Directories ready"
}

check_ports() {
  # shellcheck disable=SC1091
  source .env 2>/dev/null || true
  for p in "${GITLAB_HTTP_PORT:-8000}" "${GITLAB_HTTPS_PORT:-8443}" "${GITLAB_SSH_PORT:-2222}"; do
    if (ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null) | grep -q ":${p} "; then
      log_warn "Port ${p} is already in use"
    fi
  done
}

show_help() {
  cat <<EOF
GitLab production bootstrap

Usage:
  $0           Full deploy (init + docker compose up)
  $0 --init    Create .env and data directories only
  $0 --help    Show this help
EOF
}

init_only() {
  check_requirements
  ensure_env
  create_directories
  check_ports
  log_success "Init complete. Review .env, then run: docker compose up -d"
}

main() {
  case "${1:-}" in
    --init) init_only; exit 0 ;;
    --help|-h) show_help; exit 0 ;;
    "") ;;
    *) log_error "Unknown option: $1"; show_help; exit 1 ;;
  esac

  log_info "Deploying GitLab stack..."
  check_requirements
  ensure_env
  create_directories
  check_ports

  docker compose pull
  docker compose up -d

  # shellcheck disable=SC1091
  source .env

  log_info "Registering global instance runner (if needed)..."
  ./register-runner.sh || log_warn "Runner registration skipped or failed — retry with ./register-runner.sh"

  log_success "GitLab stack started"
  echo
  echo "URL:      ${GITLAB_URL:-http://localhost:8000}"
  echo "SSH git:  ssh://git@localhost:${GITLAB_SSH_PORT:-2222}/group/project.git"
  echo "Root:     root / (see GITLAB_ROOT_PASSWORD in .env or data/.credentials)"
  echo "Status:   docker compose ps"
  echo "Logs:     docker compose logs -f gitlab"
}

main "$@"
