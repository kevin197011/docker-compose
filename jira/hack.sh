#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONTAINER=jira
AGENT_HOST="$ROOT/atlassian-agent.jar"
AGENT_CONTAINER=/var/agent/atlassian-agent.jar
EMAIL=${EMAIL:-Hello@world.com}
ORG=${ORG:-your-org}
SID_RE='^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$'

[[ -f "$AGENT_HOST" ]] || { echo "[ERROR] missing $AGENT_HOST; run bootstrap.py first"; exit 1; }

usage() {
  cat <<EOF
Usage:
  ./hack.sh [product] [server-id]

Defaults:
  product   = jira
  server-id = auto (dbconfig.xml → container logs)

Examples:
  ./hack.sh
  ./hack.sh com.example.plugin
  SERVER_ID=AAAA-BBBB-CCCC-DDDD ./hack.sh
EOF
}

read_server_id_from_cfg() {
  docker exec "$CONTAINER" sh -c '
    for f in /var/atlassian/application-data/jira/dbconfig.xml; do
      [ -f "$f" ] || continue
      sed -n "s/.*jira.setup.server.id\">\\([^<]*\\).*/\\1/p" "$f" | head -1
      exit 0
    done
  ' 2>/dev/null || true
}

read_server_id_from_logs() {
  docker logs "$CONTAINER" 2>&1 |
    grep -oE '[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}' |
    tail -1 || true
}

detect_server_id() {
  local sid attempt
  echo "[INFO] detecting Server ID ..." >&2
  for attempt in $(seq 24); do
    sid=$(read_server_id_from_cfg)
    [[ -n "$sid" ]] || sid=$(read_server_id_from_logs)
    [[ -n "$sid" ]] && {
      echo "$sid"
      return 0
    }
    sleep 5
  done
  echo "[ERROR] Server ID not found; open Jira setup page first or set SERVER_ID" >&2
  return 1
}

hack() {
  local product=$1 sid=$2
  echo "[INFO] product=$product server-id=$sid" >&2
  docker exec "$CONTAINER" java -jar "$AGENT_CONTAINER" \
    -d -p "$product" \
    -m "$EMAIL" -n "$EMAIL" \
    -o "$ORG" -s "$sid" 2>/dev/null |
    awk '/^AAA[A-Z]/{p=1} p'
}

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
  usage
  exit 0
fi

product=jira
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
