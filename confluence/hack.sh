#!/usr/bin/env bash
set -euo pipefail

CONTAINER=confluence
AGENT=/var/agent/atlassian-agent.jar
EMAIL=${EMAIL:-Hello@world.com}
ORG=${ORG:-your-org}
SERVER_ID=${SERVER_ID:-you-server-id-xxxx}

hack() {
  docker exec "$CONTAINER" java -jar "$AGENT" \
    -d -p "$1" \
    -m "$EMAIL" -n "$EMAIL" \
    -o "$ORG" -s "$SERVER_ID"
}

# Usage:
#   ./hack.sh                         # Confluence core
#   ./hack.sh eu.softwareplant.biggantt  # plugin example: BigGantt
product=${1:-conf}
hack "$product"
