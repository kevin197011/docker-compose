#!/usr/bin/env bash
# Install Docker CE on Rocky/RHEL 9 (same path as devops-confluence-01).
set -euo pipefail

if command -v docker >/dev/null 2>&1; then
  docker --version
  systemctl enable --now docker
  exit 0
fi

sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker devops || true
docker --version
docker compose version
