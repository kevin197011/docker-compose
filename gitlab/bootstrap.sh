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
}

gen_password() { openssl rand -hex 16; }

ensure_env() {
  if [[ -f .env ]]; then
    return
  fi

  if [[ -n "$(ls -A data/postgresql 2>/dev/null)" ]]; then
    log_error "data/postgresql exists but .env is missing — restore .env or data/.credentials"
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

  log_success "Created .env (passwords in data/.credentials)"
  echo "  GitLab root: ${root_pass}"
}

create_directories() {
  mkdir -p \
    data/postgresql data/redis-cache data/redis-persistent data/redis-sessions \
    data/gitlab/{config,log,data,backups} data/gitlab-runner/config certs
  chmod +x bootstrap.sh 2>/dev/null || true
  # shellcheck disable=SC1091
  source .env
  if [ "${GITLAB_LISTEN_HTTPS:-false}" = true ]; then
    for f in "certs/${GITLAB_SSL_CERT:-gitlab.devops.com.crt}" "certs/${GITLAB_SSL_KEY:-gitlab.devops.com.key}"; do
      [ -f "$f" ] || log_warn "HTTPS enabled but missing $f"
    done
  fi
}

runner_ready() {
  [[ -f data/gitlab-runner/config/config.toml ]] && grep -q 'glrt-' data/gitlab-runner/config/config.toml
}

register_runner() {
  # shellcheck disable=SC1091
  source .env
  local cfg=data/gitlab-runner/config/config.toml
  local url="${GITLAB_INTERNAL_URL:-${GITLAB_URL:-http://gitlab}}"
  local cert="certs/${GITLAB_SSL_CERT:-gitlab.devops.com.crt}"
  local tls_ca="/etc/gitlab-runner/certs/ca.crt"

  if runner_ready; then
    if grep -q 'url = "http://gitlab"' "$cfg" && [[ "$url" == https://* ]]; then
      log_info "Updating runner URL to ${url}..."
      sed -i.bak "s|url = \"http://gitlab\"|url = \"${url}\"|" "$cfg"
      sed -i.bak "s|clone_url = \"http://gitlab\"|clone_url = \"${url}\"|" "$cfg"
      rm -f "${cfg}.bak"
      grep -q 'tls-ca-file' "$cfg" || {
        sed -i.bak "/^  url = /a\\
  tls-ca-file = \"${tls_ca}\"
" "$cfg"
        rm -f "${cfg}.bak"
      }
    fi
    return 0
  fi

  log_info "Registering instance runner..."
  until docker exec gitlab gitlab-rails runner 'puts :ok' 2>/dev/null | grep -q ok; do sleep 5; done

  local token name image
  name="${GITLAB_RUNNER_NAME:-gitlab-shared-runner}"
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

  local -a cmd=(
    docker run --rm --network gitlab_net
    -v "$(pwd)/data/gitlab-runner/config:/etc/gitlab-runner"
    -v /var/run/docker.sock:/var/run/docker.sock
  )
  [[ "$url" == https://* && -f "$cert" ]] && cmd+=(-v "$(pwd)/${cert}:${tls_ca}:ro")
  cmd+=(
    "$image" register --non-interactive
    --url "$url" --clone-url "$url" --token "$token"
    --executor docker --description "$name"
    --docker-image docker:27-alpine
    --docker-volumes /var/run/docker.sock:/var/run/docker.sock
    --docker-volumes /cache --docker-network-mode gitlab_net --docker-privileged
  )
  [[ "$url" == https://* && -f "$cert" ]] && cmd+=(--tls-ca-file "$tls_ca")
  "${cmd[@]}"
  chmod 644 "$cfg"
  log_success "Runner registered"
}

reload_certs() {
  # shellcheck disable=SC1091
  source .env
  [[ "${GITLAB_LISTEN_HTTPS:-false}" == true ]] || return 0
  local cert="certs/${GITLAB_SSL_CERT:-gitlab.devops.com.crt}"
  local key="certs/${GITLAB_SSL_KEY:-gitlab.devops.com.key}"
  [[ -f "$cert" && -f "$key" ]] || return 0
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx gitlab || return 0
  docker exec gitlab gitlab-ctl hup nginx >/dev/null 2>&1 && log_success "HTTPS certs loaded"
}

main() {
  [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && {
    echo "Usage: $0   # init (if needed) + pull + up + runner + certs"
    exit 0
  }
  [[ -n "${1:-}" ]] && { log_error "Unknown option: $1 (just run $0)"; exit 1; }

  log_info "GitLab deploy/update..."
  check_requirements
  ensure_env
  create_directories

  docker compose pull
  runner_ready || docker compose up -d postgresql redis-cache redis-persistent redis-sessions gitlab
  register_runner
  docker compose up -d
  reload_certs

  # shellcheck disable=SC1091
  source .env
  log_success "Done — data/ preserved"
  echo "URL:    ${GITLAB_URL}"
  echo "Root:   cat data/.credentials"
  echo "Status: docker compose ps"
}

main "$@"
