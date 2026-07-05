#!/usr/bin/env bash
set -euo pipefail

CONTAINER=jira
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
#   ./hack.sh                    # Jira core
#   ./hack.sh com.example.plugin # plugin example
product=${1:-jira}
hack "$product"
