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

  if [[ -n "$(ls -A data/postgresql 2>/dev/null)" ]]; then
    log_error "data/postgresql exists but .env is missing — restore .env (or data/.credentials), do not regenerate passwords"
    exit 1
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
    data/gitlab-runner/config \
    certs
  chmod +x bootstrap.sh register-runner.sh 2>/dev/null || true
  # shellcheck disable=SC1091
  source .env 2>/dev/null || true
  if [ "${GITLAB_LISTEN_HTTPS:-false}" = true ]; then
    for f in "certs/${GITLAB_SSL_CERT:-gitlab.devops.com.crt}" "certs/${GITLAB_SSL_KEY:-gitlab.devops.com.key}"; do
      [ -f "$f" ] || log_warn "HTTPS enabled but missing $f"
    done
  fi
  log_success "Directories ready"
}

check_ports() {
  # ponytail: skip on re-deploy — compose will error if ports truly conflict
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx gitlab && return 0

  # shellcheck disable=SC1091
  source .env 2>/dev/null || true
  for p in "${GITLAB_HTTP_PORT:-80}" "${GITLAB_HTTPS_PORT:-443}" "${GITLAB_SSH_PORT:-2222}"; do
    lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 || continue
    log_warn "Port ${p} is in use — stop the other service or change GITLAB_*_PORT in .env"
  done
}

register_runner() {
  # shellcheck disable=SC1091
  source .env
  local cfg=data/gitlab-runner/config/config.toml
  if [[ -f "$cfg" ]] && grep -q 'glrt-' "$cfg"; then
    log_success "Runner already registered"
    return 0
  fi

  docker ps --format '{{.Names}}' | grep -qx gitlab || {
    log_error "gitlab container not running"
    return 1
  }

  log_info "Waiting for GitLab..."
  until docker exec gitlab gitlab-rails runner 'puts :ok' 2>/dev/null | grep -q ok; do sleep 5; done

  log_info "Creating instance runner..."
  local token name url image
  name="${GITLAB_RUNNER_NAME:-gitlab-shared-runner}"
  url="${GITLAB_INTERNAL_URL:-http://gitlab}"
  image="gitlab/gitlab-runner:${GITLAB_RUNNER_VERSION:-alpine-v18.11.4}"

  token=$(docker exec gitlab gitlab-rails runner "
    r = Ci::Runners::CreateRunnerService.new(
      user: User.find_by(username: 'root'),
      params: {
        runner_type: 'instance_type',
        description: '${name}',
        tag_list: '${GITLAB_RUNNER_TAG_LIST:-docker,shared}',
        run_untagged: true,
        locked: false
      }
    ).execute
    raise r.message unless r.success?
    puts r.payload[:runner].token
  " 2>/dev/null | grep '^glrt-' | tr -d '\r\n')

  docker run --rm --network gitlab_net \
    -v "$(pwd)/data/gitlab-runner/config:/etc/gitlab-runner" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$image" register --non-interactive \
    --url "$url" --clone-url "$url" --token "$token" \
    --executor docker --description "$name" \
    --docker-image docker:27-alpine \
    --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
    --docker-volumes /cache \
    --docker-network-mode gitlab_net \
    --docker-privileged

  chmod 644 "$cfg"
  log_success "Runner registered (instance, global)"
}

is_existing_deploy() {
  [[ -f data/gitlab/config/gitlab.rb ]]
}

deploy_stack() {
  docker compose pull
  if is_existing_deploy; then
    log_info "Existing install — rolling update (data/ and .env unchanged)"
    docker compose up -d
    register_runner
    return
  fi

  log_info "First install — starting core services, then runner..."
  docker compose up -d postgresql redis-cache redis-persistent redis-sessions gitlab
  register_runner
  docker compose up -d gitlab-runner
}

reload_certs() {
  # shellcheck disable=SC1091
  source .env
  local cert="certs/${GITLAB_SSL_CERT:-gitlab.devops.com.crt}"
  local key="certs/${GITLAB_SSL_KEY:-gitlab.devops.com.key}"
  for f in "$cert" "$key"; do
    [[ -f "$f" ]] || { log_error "Missing $f"; exit 1; }
  done
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx gitlab || {
    log_error "gitlab not running — start with: docker compose up -d gitlab"
    exit 1
  }
  log_info "Reloading nginx with certs from ./certs/ (no data migration)..."
  docker exec gitlab gitlab-ctl hup nginx
  log_success "HTTPS certs reloaded — database, repos, and Redis untouched"
}

show_help() {
  cat <<EOF
GitLab bootstrap

  $0                    Deploy or update (preserves data/ on repeat runs)
  $0 --init             Create .env and directories only (first time)
  $0 --certs            Reload HTTPS certs after replacing files in certs/
  $0 --register-runner  Register runner only (needs gitlab running)
  $0 --help

Repeat deploy / version bump: safe — bind mounts under data/ are never removed.
Cert rotation: replace certs/*.crt and *.key, then run $0 --certs
EOF
}

init_only() {
  check_requirements
  ensure_env
  create_directories
  check_ports
  log_success "Init complete — run: docker compose up -d"
}

main() {
  case "${1:-}" in
    --init) init_only; exit 0 ;;
    --certs) check_requirements; ensure_env; reload_certs; exit 0 ;;
    --register-runner) check_requirements; ensure_env; register_runner; exit $? ;;
    --help|-h) show_help; exit 0 ;;
    "") ;;
    *) log_error "Unknown option: $1"; show_help; exit 1 ;;
  esac

  log_info "Deploying GitLab..."
  check_requirements
  ensure_env
  create_directories
  deploy_stack

  # shellcheck disable=SC1091
  source .env
  log_success "Done"
  echo
  echo "URL:    ${GITLAB_URL}"
  echo "SSH:    ssh://git@${GITLAB_URL#*://}/...  (port ${GITLAB_SSH_PORT:-2222})"
  echo "Root:   see data/.credentials"
  echo "Status: docker compose ps"
}

main "$@"
