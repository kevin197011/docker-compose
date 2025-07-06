#!/bin/bash
# Bootstrap script for Nacos
set -e

cd "$(dirname "$0")"
echo "Starting Nacos container..."
docker compose -f compose.yml up -d
