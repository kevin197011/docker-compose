#!/bin/bash

# 确保脚本抛出遇到的错误
set -e

# 创建必要的目录
mkdir -p data/postgresql
mkdir -p data/redis
mkdir -p media
mkdir -p custom-templates
mkdir -p certs

# 生成随机密码和密钥
PG_PASS=$(openssl rand -hex 16)
REDIS_PASS=$(openssl rand -hex 16)
AUTHENTIK_SECRET_KEY=$(openssl rand -hex 32)

# 设置默认环境变量
if [ ! -f .env ]; then
  cat > .env << EOF
# PostgreSQL 配置
PG_PASS=${PG_PASS}
PG_USER=authentik
PG_DB=authentik

# Redis 配置
REDIS_PASS=${REDIS_PASS}

# Authentik 配置
AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}
AUTHENTIK_ERROR_REPORTING__ENABLED=false
AUTHENTIK_POSTGRESQL__HOST=postgresql
AUTHENTIK_POSTGRESQL__USER=authentik
AUTHENTIK_POSTGRESQL__PASSWORD=authentik
AUTHENTIK_POSTGRESQL__NAME=authentik
AUTHENTIK_REDIS__HOST=redis
AUTHENTIK_REDIS__PASSWORD=authentik_redis
AUTHENTIK_PORT=9000
AUTHENTIK_PORT_API=9443

# 端口配置（可选）
COMPOSE_PORT_HTTP=9000
COMPOSE_PORT_HTTPS=9443

# Authentik 版本配置（可选）
AUTHENTIK_IMAGE=ghcr.io/goauthentik/server
AUTHENTIK_TAG=2025.6.3

# SMTP 配置（可选，建议在生产环境配置）
#AUTHENTIK_EMAIL__HOST=smtp.gmail.com
#AUTHENTIK_EMAIL__PORT=587
#AUTHENTIK_EMAIL__USERNAME=your-email@gmail.com
#AUTHENTIK_EMAIL__PASSWORD=your-app-specific-password
#AUTHENTIK_EMAIL__USE_TLS=true
#AUTHENTIK_EMAIL__FROM=your-email@gmail.com

# 管理员账号配置
AUTHENTIK_BOOTSTRAP_PASSWORD=admin123
AUTHENTIK_BOOTSTRAP_TOKEN=admin123
AUTHENTIK_BOOTSTRAP_EMAIL=admin@example.com
EOF

  echo "已创建 .env 文件并生成随机密码"
  echo "PostgreSQL 密码: ${PG_PASS}"
  echo "Redis 密码: ${REDIS_PASS}"
  echo "管理员账号: admin@example.com"
  echo "管理员密码: admin123"
  echo "请妥善保存这些密码！"
fi

echo "Authentik 环境初始化成功！"