#!/bin/bash

# Gitea + Drone CI/CD 一体化部署脚本
# 集成环境初始化、配置和部署功能
# Copyright (c) 2024
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 自动获取IP地址函数
get_ip_address() {
    local ip_address=""

    # 检测操作系统
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS 系统
        # 方法1: 使用 route 命令获取默认路由的IP
        ip_address=$(route get default 2>/dev/null | grep interface | awk '{print $2}' | head -1)
        if [[ -n "$ip_address" ]]; then
            ip_address=$(ifconfig "$ip_address" 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
        fi

        # 方法2: 使用 ifconfig 获取第一个活跃的非回环IP
        if [[ -z "$ip_address" ]]; then
            ip_address=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
        fi
    else
        # Linux 系统
        # 方法1: 优先使用默认路由的网卡IP
        if command -v ip &> /dev/null; then
            ip_address=$(ip route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | awk '{print $2}' | head -1)
        fi

        # 方法2: 如果方法1失败，尝试获取第一个非回环接口的IP
        if [[ -z "$ip_address" ]] && command -v ip &> /dev/null; then
            ip_address=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)
        fi

        # 方法3: 使用hostname命令
        if [[ -z "$ip_address" ]] && command -v hostname &> /dev/null; then
            ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
        fi
    fi

    # 方法4: 最后尝试curl获取外网IP（如果有网络）
    if [[ -z "$ip_address" ]]; then
        ip_address=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "")
    fi

        # 过滤掉IPv6地址，只保留IPv4
    if [[ -n "$ip_address" && "$ip_address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 不在这里输出日志，避免污染返回值
        echo "$ip_address"
    else
        echo "localhost"
    fi
}

# 清理其他项目目录函数
cleanup_other_directories() {
    log_info "清理其他项目目录..."

    # 当前目录名
    current_dir=$(basename "$(pwd)")

    # 切换到上级目录
    cd ../

    # 构建find命令，只保留当前目录
    find_cmd="find . -maxdepth 1 ! -name '.' ! -name '$current_dir' -exec rm -rf {} +"

    # 显示将要执行的命令
    log_info "将执行清理命令: $find_cmd"

    # 询问用户确认
    echo ""
    log_warn "此操作将删除除了 '$current_dir' 目录之外的所有文件和目录"
    echo ""
    read -p "是否继续? (y/N): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        eval "$find_cmd" 2>/dev/null || log_warn "清理过程中可能有些文件无法删除"
        log_success "清理完成"
    else
        log_info "已取消清理操作"
    fi

    # 切换回原目录
    cd "$current_dir"
}

# 生成随机密钥
generate_secret() {
    openssl rand -hex 16 2>/dev/null || echo "$(date +%s | sha256sum | head -c 32)"
}

# 检查必要的命令
check_requirements() {
    log_info "检查系统要求..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! command -v docker compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi

    log_success "系统要求检查通过"
}

# 创建基本目录结构
create_directories() {
    log_info "创建目录结构..."

    # 根据项目需要创建目录
    mkdir -p data/gitea data/drone logs config

    # 创建 Gitea 配置目录
    mkdir -p data/gitea/git data/gitea/ssh

    # 设置正确的权限
    chmod -R 755 data/

    log_success "目录结构创建完成"
}

# 设置目录权限
set_permissions() {
    log_info "设置目录权限..."

    # 设置基本权限
    chmod -R 755 data/ 2>/dev/null || true
    chmod -R 755 logs/ 2>/dev/null || true
    chmod -R 755 config/ 2>/dev/null || true

    # 设置脚本执行权限
    chmod +x bootstrap.sh 2>/dev/null || true

    log_success "权限设置完成"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."

    # 检查 Gitea 端口
    if netstat -tuln 2>/dev/null | grep -q ":3000 " || ss -tuln 2>/dev/null | grep -q ":3000 "; then
        log_warn "端口 3000 (Gitea) 已被占用"
    fi

    # 检查 Drone 端口
    if netstat -tuln 2>/dev/null | grep -q ":3001 " || ss -tuln 2>/dev/null | grep -q ":3001 "; then
        log_warn "端口 3001 (Drone) 已被占用"
    fi

    # 检查 SSH 端口
    if netstat -tuln 2>/dev/null | grep -q ":2222 " || ss -tuln 2>/dev/null | grep -q ":2222 "; then
        log_warn "端口 2222 (Gitea SSH) 已被占用"
    fi

    # 检查 Drone Runner 端口
    if netstat -tuln 2>/dev/null | grep -q ":3002 " || ss -tuln 2>/dev/null | grep -q ":3002 "; then
        log_warn "端口 3002 (Drone Runner) 已被占用"
    fi

    log_success "端口检查完成"
}

# 显示帮助信息
show_help() {
    echo "Gitea + Drone CI/CD 一体化部署脚本"
    echo ""
    echo "用法:"
    echo "  $0                      完整部署（推荐）"
    echo "  $0 --init              仅初始化环境"
    echo "  $0 --cleanup           清理其他项目目录"
    echo "  $0 --help              显示帮助信息"
    echo ""
    echo "功能说明:"
    echo "  默认模式    : 检查环境 -> 初始化 -> 部署服务"
    echo "  --init     : 仅创建目录、设置权限、检查端口"
    echo "  --cleanup  : 清理上级目录中除当前目录外的所有文件"
    echo ""
    echo "环境变量:"
    echo "  GITEA_VERSION          Gitea 版本 (默认: 1.21.5)"
    echo "  DRONE_VERSION          Drone 版本 (默认: 2.23.0)"
    echo "  DRONE_RUNNER_VERSION   Runner 版本 (默认: 1.8.3)"
    echo "  IP_ADDRESS             IP地址 (默认: 自动获取)"
    echo "  GITEA_ADMIN_USER       管理员用户名 (默认: root)"
    echo ""
}

# 仅初始化环境
init_only() {
    log_info "开始初始化项目环境..."

    # 检查系统要求
    check_requirements

    # 询问是否需要先清理其他目录
    echo ""
    read -p "是否需要先清理其他项目目录? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_other_directories
        echo ""
    fi

    # 执行初始化步骤
    create_directories
    set_permissions
    check_ports

    log_success "项目环境初始化完成！"
    echo ""
    echo "🚀 接下来的步骤："
    echo "1. 快速部署: ./bootstrap.sh"
    echo "2. 或手动启动: docker compose up -d"
    echo "3. 查看日志: docker compose logs -f"
    echo "4. 停止服务: docker compose down"
    echo ""
    echo "🌐 服务端口："
    echo "- Gitea: http://localhost:3000"
    echo "- Drone: http://localhost:3001"
    echo "- Drone Runner: http://localhost:3002"
    echo "- Gitea SSH: localhost:2222"
    echo ""
}

# 主函数
main() {
    # 处理命令行参数
    case "${1:-}" in
        --init)
            init_only
            exit 0
            ;;
        --cleanup)
            cleanup_other_directories
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # 默认行为：完整部署
            ;;
        *)
            log_error "未知参数: $1"
            echo "使用 $0 --help 查看帮助信息"
            exit 1
            ;;
    esac

    log_info "开始 Gitea + Drone CI/CD 一体化部署..."

    # 检查系统要求
    check_requirements

    # 询问是否需要先清理其他目录
    echo ""
    read -p "是否需要先清理其他项目目录? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_other_directories
        echo ""
    fi

    # 执行初始化步骤
    create_directories
    set_permissions
    check_ports

    # 设置环境变量
    export HOSTNAME=$(hostname)
    export DRONE_VERSION=${DRONE_VERSION:-2.23.0}
    export DRONE_RUNNER_VERSION=${DRONE_RUNNER_VERSION:-1.8.3}
    export GITEA_VERSION=${GITEA_VERSION:-1.21.5}
    export IP_ADDRESS=$(get_ip_address)
    export GITEA_ADMIN_USER=${GITEA_ADMIN_USER:-"root"}
    export DRONE_RPC_SECRET=$(generate_secret)
    export DRONE_USER_CREATE="username:${GITEA_ADMIN_USER},machine:false,admin:true,token:${DRONE_RPC_SECRET}"
    export DRONE_GITEA_CLIENT_ID=${DRONE_GITEA_CLIENT_ID:-""}
    export DRONE_GITEA_CLIENT_SECRET=${DRONE_GITEA_CLIENT_SECRET:-""}

    # 显示IP获取结果
    if [[ "$IP_ADDRESS" == "localhost" ]]; then
        log_warn "无法自动获取IPv4地址，使用默认值: localhost"
    else
        log_success "自动获取到IP地址: $IP_ADDRESS"
    fi

    # 显示配置信息
    log_info "配置信息:"
    echo "  主机名: $HOSTNAME"
    echo "  IP地址: $IP_ADDRESS"
    echo "  Gitea版本: $GITEA_VERSION"
    echo "  Drone版本: $DRONE_VERSION"
    echo "  Drone Runner版本: $DRONE_RUNNER_VERSION"
    echo "  管理员用户: $GITEA_ADMIN_USER"
    echo "  RPC密钥: ${DRONE_RPC_SECRET:0:8}..."
    echo ""

    # 启动服务
    log_info "启动服务..."
    docker compose up -d

    # 等待服务启动
    log_info "等待服务启动完成..."
    sleep 10

    # 显示访问信息
    echo ""
    log_success "部署完成！"
    echo ""
    echo "🌐 访问地址:"
    echo "  Gitea: http://${IP_ADDRESS}:3000/"
    echo "  Drone: http://${IP_ADDRESS}:3001/"
    echo "  Drone Runner: http://${IP_ADDRESS}:3002/"
    echo ""
    echo "👤 默认账户:"
    echo "  用户名: $GITEA_ADMIN_USER"
    echo "  密码: 首次访问时设置"
    echo ""
    echo "🔧 配置说明:"
    echo "  1. 首先访问 Gitea 完成初始化设置"
    echo "  2. 在 Gitea 中创建 OAuth2 应用获取 Client ID 和 Secret"
    echo "  3. 使用获取的凭据配置 Drone"
    echo ""
    echo "📝 RPC 密钥 (用于 Drone 配置): $DRONE_RPC_SECRET"
    echo ""
    echo "📊 查看服务状态: docker compose ps"
    echo "📋 查看日志: docker compose logs -f"
    echo ""
}

# 运行主函数
main "$@"