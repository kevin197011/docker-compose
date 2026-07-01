#!/bin/bash
# Register a GitLab 18+ instance runner (global, run_untagged) via Rails API.
set -euo pipefail

cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

[[ -f .env ]] || { log_error "Missing .env — run ./bootstrap.sh --init first"; exit 1; }
# shellcheck disable=SC1091
source .env

CONFIG="data/gitlab-runner/config/config.toml"

runner_config_valid() {
  [[ -f "$CONFIG" ]] || return 1
  grep -q 'url =' "$CONFIG" || return 1
  # reject configs where log output was captured into token (seen with glrt- tokens)
  grep -q 'token = "glrt-' "$CONFIG" || return 1
  ! grep -qE 'token = ".*\\u001b|token = ".*\[INFO\]' "$CONFIG"
}

if runner_config_valid; then
  log_success "Runner already registered ($(basename "$CONFIG"))"
  exit 0
fi

if [[ -f "$CONFIG" ]]; then
  log_warn "Removing invalid runner config (corrupt token)..."
  rm -f "$CONFIG"
fi

RUNNER_NAME="${GITLAB_RUNNER_NAME:-gitlab-shared-runner}"
RUNNER_TAGS="${GITLAB_RUNNER_TAG_LIST:-docker,shared}"
INTERNAL_URL="${GITLAB_INTERNAL_URL:-http://gitlab}"
IMAGE="gitlab/gitlab-runner:${GITLAB_RUNNER_VERSION:-alpine-v18.11.4}"
PRIVILEGED="${GITLAB_RUNNER_PRIVILEGED:-true}"

wait_for_gitlab() {
  log_info "Waiting for GitLab Rails..."
  local i=0
  until docker exec gitlab gitlab-rails runner 'puts :ok' 2>/dev/null | grep -q ok; do
    i=$((i + 1))
    if (( i > 120 )); then
      log_error "GitLab not ready after 10 minutes"
      exit 1
    fi
    sleep 5
  done
}

create_runner_token() {
  log_info "Creating instance runner token (global)..."
  docker exec gitlab gitlab-rails runner "
    user = User.find_by(username: 'root')
    raise 'root user not found' unless user

    result = Ci::Runners::CreateRunnerService.new(
      user: user,
      params: {
        runner_type: 'instance_type',
        description: '${RUNNER_NAME}',
        tag_list: '${RUNNER_TAGS}',
        run_untagged: true,
        locked: false
      }
    ).execute

    raise result.message unless result.success?

    runner = result.payload[:runner]
    token = runner.token
    raise 'missing glrt token' unless token.to_s.start_with?('glrt-')
    puts token
  " 2>/dev/null | grep '^glrt-' | tr -d '\r\n'
}

register_runner() {
  local token=$1
  log_info "Registering runner with executor=docker..."

  # glrt- auth tokens: runner attrs are set in CreateRunnerService; only pass executor/docker opts here
  local -a register_cmd=(
    docker run --rm
    --network gitlab_net
    -v "$(pwd)/data/gitlab-runner/config:/etc/gitlab-runner"
    -v /var/run/docker.sock:/var/run/docker.sock
    --user 0:0
    "$IMAGE"
    register
    --non-interactive
    --url "$INTERNAL_URL"
    --clone-url "$INTERNAL_URL"
    --token "$token"
    --executor docker
    --description "$RUNNER_NAME"
    --docker-image docker:27-alpine
    --docker-volumes /var/run/docker.sock:/var/run/docker.sock
    --docker-volumes /cache
    --docker-network-mode gitlab_net
  )

  if [[ "$PRIVILEGED" == "true" ]]; then
    register_cmd+=(--docker-privileged)
  fi

  "${register_cmd[@]}"
}

main() {
  command -v docker >/dev/null || { log_error "Docker required"; exit 1; }
  docker ps --format '{{.Names}}' | grep -qx gitlab || {
    log_error "gitlab container is not running — start with: docker compose up -d"
    exit 1
  }

  wait_for_gitlab
  token=$(create_runner_token)
  [[ "$token" == glrt-* ]] || { log_error "Invalid runner token: ${token:-<empty>}"; exit 1; }

  register_runner "$token"
  docker compose restart gitlab-runner >/dev/null

  log_success "Instance runner registered (global, run_untagged=true, tags=${RUNNER_TAGS})"
  echo "  Admin → CI/CD → Runners → Instance runners"
}

main "$@"
