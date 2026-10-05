#!/usr/bin/env bash
# Generate Confluence / plugin license via haxqer agent (baked into image).
# Ref: https://juejin.cn/post/7409882784058605579
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
AGENT_HOST="$ROOT/atlassian-agent.jar"
AGENT_CONTAINER=/var/agent/atlassian-agent.jar
EMAIL=${EMAIL:-Hello@world.com}
ORG=${ORG:-your-org}
SID_RE='^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$'

# Prefer DOCKER=sudo\ docker when user not in docker group
if [[ -n "${DOCKER:-}" ]]; then
  :
elif docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif sudo docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
else
  echo "[ERROR] docker not available" >&2
  exit 1
fi

resolve_container() {
  if [[ -n "${CONTAINER:-}" ]]; then
    echo "$CONTAINER"
    return
  fi
  local c
  for c in wiki confluence9 confluence; do
    if "${DOCKER[@]}" inspect "$c" >/dev/null 2>&1; then
      echo "$c"
      return
    fi
  done
  echo "[ERROR] no running confluence container (tried wiki / confluence9 / confluence); set CONTAINER=" >&2
  exit 1
}

CONTAINER="$(resolve_container)"

usage() {
  cat <<EOF
Usage:
  ./hack.sh [product] [server-id]

Defaults:
  product   = conf
  server-id = auto (confluence.cfg.xml → container logs)
  container = auto (wiki | confluence9 | confluence) or \$CONTAINER

Examples:
  ./hack.sh
  ./hack.sh eu.softwareplant.biggantt
  SERVER_ID=BVU1-MNSF-GZIT-Z3XT ./hack.sh
  CONTAINER=wiki ./hack.sh
EOF
}

agent_path() {
  if "${DOCKER[@]}" exec "$CONTAINER" test -f "$AGENT_CONTAINER" 2>/dev/null; then
    echo "$AGENT_CONTAINER"
    return
  fi
  if [[ -f "$AGENT_HOST" ]]; then
    "${DOCKER[@]}" cp "$AGENT_HOST" "$CONTAINER:/tmp/atlassian-agent.jar" >/dev/null
    echo /tmp/atlassian-agent.jar
    return
  fi
  echo "[ERROR] agent not found in container or $AGENT_HOST; run bootstrap.py" >&2
  exit 1
}

read_server_id_from_cfg() {
  # haxqer home = /var/confluence
  "${DOCKER[@]}" exec "$CONTAINER" sh -c '
    for f in \
      /var/confluence/confluence.cfg.xml \
      /var/confluence/shared-home/confluence.cfg.xml \
      /var/atlassian/application-data/confluence/confluence.cfg.xml; do
      [ -f "$f" ] || continue
      sed -n "s/.*confluence.setup.server.id\">\\([^<]*\\).*/\\1/p" "$f" | head -1
      exit 0
    done
  ' 2>/dev/null || true
}

read_server_id_from_logs() {
  "${DOCKER[@]}" logs "$CONTAINER" 2>&1 |
    grep -oE '[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}' |
    tail -1 || true
}

detect_server_id() {
  local sid attempt
  echo "[INFO] container=$CONTAINER detecting Server ID ..." >&2
  for attempt in $(seq 12); do
    sid=$(read_server_id_from_cfg)
    [[ -n "$sid" ]] || sid=$(read_server_id_from_logs)
    [[ -n "$sid" ]] && {
      echo "[INFO] server-id=$sid" >&2
      echo "$sid"
      return 0
    }
    sleep 2
  done
  echo "[ERROR] Server ID not found; open Confluence setup/license page first or set SERVER_ID" >&2
  return 1
}

hack() {
  local product=$1 sid=$2 agent
  agent=$(agent_path)
  echo "[INFO] product=$product server-id=$sid agent=$agent container=$CONTAINER" >&2
  "${DOCKER[@]}" exec "$CONTAINER" java -jar "$agent" \
    -d -p "$product" \
    -m "$EMAIL" -n "$EMAIL" \
    -o "$ORG" -s "$sid" 2>/dev/null |
    awk '/^AAA[A-Z]/{p=1} p'
}

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
  usage
  exit 0
fi

product=conf
server_id=${SERVER_ID:-}

case $# in
  0) ;;
  1)
    if [[ "$1" =~ $SID_RE ]]; then
      server_id=$1
    else
      product=$1
    fi
    ;;
  *)
    product=$1
    server_id=$2
    ;;
esac

if [[ -z "$server_id" ]]; then
  server_id=$(detect_server_id)
fi

hack "$product" "$server_id"
