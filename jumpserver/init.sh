#!/bin/bash

# JumpServer Docker Compose 初始化脚本
# Author: Docker Compose JumpServer Setup
# Description: 自动创建目录结构和设置必要的权限

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi

    log_info "Docker 和 Docker Compose 检查通过"
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."

    # 数据目录
    mkdir -p data/{mysql,redis,core/{media,static},koko,lion,magnus}

    # 日志目录
    mkdir -p logs/{core,koko,lion,magnus}

    # 配置目录已经存在，无需创建

    log_info "目录结构创建完成"
}

# 设置目录权限
set_permissions() {
    log_info "设置目录权限..."

    # 设置基本权限
    chmod -R 755 data/
    chmod -R 755 logs/
    chmod -R 755 config/

    # 设置脚本执行权限
    chmod +x init.sh

    # 如果是 Linux 系统，设置 MySQL 和 Redis 目录权限
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # MySQL 用户 ID 999
        sudo chown -R 999:999 data/mysql 2>/dev/null || log_warn "无法设置 MySQL 目录权限，请手动执行: sudo chown -R 999:999 data/mysql"

        # Redis 用户 ID 999
        sudo chown -R 999:999 data/redis 2>/dev/null || log_warn "无法设置 Redis 目录权限，请手动执行: sudo chown -R 999:999 data/redis"
    fi

    log_info "权限设置完成"
}

# 生成随机密钥
generate_secrets() {
    log_info "生成安全密钥建议..."

    echo "请将以下随机生成的密钥替换到 compose.yml 文件中："
    echo ""
    echo "SECRET_KEY: \"$(openssl rand -base64 32 | tr -d '\n')\""
    echo "BOOTSTRAP_TOKEN: \"$(openssl rand -hex 16)\""
    echo "MYSQL_ROOT_PASSWORD: \"$(openssl rand -base64 16 | tr -d '\n')\""
    echo "MYSQL_PASSWORD: \"$(openssl rand -base64 16 | tr -d '\n')\""
    echo "REDIS_PASSWORD: \"$(openssl rand -base64 16 | tr -d '\n')\""
    echo ""
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."

    ports=(80 2222 3306 6379 8080)
    occupied_ports=()

    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            occupied_ports+=($port)
        fi
    done

    if [ ${#occupied_ports[@]} -gt 0 ]; then
        log_warn "以下端口已被占用: ${occupied_ports[*]}"
        log_warn "请确保这些端口可用或修改 compose.yml 中的端口配置"
    else
        log_info "所有端口检查通过"
    fi
}

# 创建环境文件
create_env_file() {
    if [ ! -f .env ]; then
        log_info "创建环境配置文件..."
        cat > .env << EOF
# JumpServer 环境配置
COMPOSE_PROJECT_NAME=jumpserver

# 时区设置
TZ=Asia/Shanghai

# 网络设置
JUMPSERVER_NETWORK=jumpserver_net

# 版本标签
JUMPSERVER_VERSION=latest
EOF
        log_info ".env 文件创建完成"
    else
        log_info ".env 文件已存在，跳过创建"
    fi
}

# 显示使用说明
show_usage() {
    log_info "初始化完成！"
    echo ""
    echo "接下来的步骤："
    echo "1. 如需要，请修改 compose.yml 中的密码和密钥"
    echo "2. 启动服务: docker-compose up -d"
    echo "3. 查看日志: docker-compose logs -f"
    echo "4. 访问管理界面: http://localhost"
    echo "5. 默认管理员账号: admin/admin (请立即修改密码)"
    echo ""
    echo "更多信息请查看 README.md 文件"
}

# 主函数
main() {
    log_info "开始初始化 JumpServer 环境..."

    check_docker
    create_directories
    set_permissions
    create_env_file
    check_ports
    generate_secrets
    show_usage

    log_info "初始化脚本执行完成！"
}

# 运行主函数
main "$@"