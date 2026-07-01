#!/bin/bash
# Create root/cicd-smoke-test and verify instance runner executes a pipeline.
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck disable=SC1091
[[ -f .env ]] && source .env

GITLAB_URL="${GITLAB_URL:-http://localhost:8000}"
PROJECT="${CI_SMOKE_PROJECT:-cicd-smoke-test}"

log() { echo "[ci-smoke] $*"; }

api_pat() {
  docker exec gitlab gitlab-rails runner "
    user = User.find_by(username: 'root')
    name = 'ci-smoke-test'
    plain = 'smoke_' + SecureRandom.hex(16)
    user.personal_access_tokens.where(name: name).delete_all
    t = user.personal_access_tokens.new(name: name, scopes: [:api], expires_at: 7.days.from_now)
    t.set_token(plain)
    t.save!
    puts plain
  " 2>/dev/null | grep '^smoke_'
}

wait_pipeline() {
  local pat=$1 id=$2
  for _ in $(seq 1 40); do
    local st
    st=$(curl -sf -H "PRIVATE-TOKEN: $pat" "$GITLAB_URL/api/v4/projects/$id/pipelines?per_page=1" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['status'])")
    log "pipeline status=$st"
    case "$st" in
      success) return 0 ;;
      failed|canceled) return 1 ;;
    esac
    sleep 4
  done
  return 1
}

main() {
  command -v docker >/dev/null || { echo "docker required"; exit 1; }
  docker ps --format '{{.Names}}' | grep -qx gitlab || { echo "start gitlab first"; exit 1; }

  local pat proj_id
  pat=$(api_pat)
  log "API token ready"

  proj_id=$(curl -sf -H "PRIVATE-TOKEN: $pat" "$GITLAB_URL/api/v4/projects/root%2F$PROJECT" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || true)

  if [[ -z "$proj_id" ]]; then
    proj_id=$(curl -sf -X POST -H "PRIVATE-TOKEN: $pat" \
      --data "name=$PROJECT" --data "path=$PROJECT" --data "visibility=private" \
      "$GITLAB_URL/api/v4/projects" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    log "created project id=$proj_id"

    curl -sf -X POST -H "PRIVATE-TOKEN: $pat" \
      --data-urlencode "branch=main" \
      --data-urlencode "content=stages:
  - test

smoke:
  stage: test
  image: alpine:3.20
  script:
    - echo CI/CD smoke test OK
    - uname -a
" \
      --data-urlencode "commit_message=Add CI smoke test" \
      "$GITLAB_URL/api/v4/projects/$proj_id/repository/files/.gitlab-ci.yml" >/dev/null
  else
    log "project exists id=$proj_id"
  fi

  curl -sf -X POST -H "PRIVATE-TOKEN: $pat" \
    "$GITLAB_URL/api/v4/projects/$proj_id/pipeline?ref=main" >/dev/null
  log "pipeline triggered"

  if wait_pipeline "$pat" "$proj_id"; then
    log "PASS — $GITLAB_URL/root/$PROJECT/-/pipelines"
    exit 0
  fi
  log "FAIL — check $GITLAB_URL/root/$PROJECT/-/jobs"
  exit 1
}

main "$@"
