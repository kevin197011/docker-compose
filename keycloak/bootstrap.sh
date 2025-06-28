#!/bin/bash

# 确保脚本抛出遇到的错误
set -e

# 创建必要的目录
mkdir -p data

# 设置默认环境变量
if [ ! -f .env ]; then
  cat > .env << EOF
# Keycloak 配置
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin123
KC_DB=postgres
KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak
KC_DB_USERNAME=keycloak
KC_DB_PASSWORD=keycloak
KC_HOSTNAME=localhost
KC_PROXY=edge

# PostgreSQL 配置
POSTGRES_DB=keycloak
POSTGRES_USER=keycloak
POSTGRES_PASSWORD=keycloak
EOF
fi

echo "Keycloak environment initialized successfully!"