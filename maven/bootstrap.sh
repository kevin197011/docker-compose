#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

[[ -f .env ]] || cp .env.example .env
mkdir -p data/nexus-data
# ponytail: nexus image runs as UID 200 — fix bind-mount ownership without host sudo
docker run --rm -v "$(pwd)/data/nexus-data:/nexus-data" alpine chown -R 200:200 /nexus-data

docker compose pull
docker compose up -d

# shellcheck disable=SC1091
source .env
echo "Nexus:  ${NEXUS_URL:-http://localhost:8081}"
echo "Pass:   cat data/nexus-data/admin.password"
echo "Maven:  config/settings.xml → ~/.m2/settings.xml"
