#!/bin/bash

# Gitea 一体化部署脚本
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
    mkdir -p data logs config

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

    # 检查 Gitea 端口 3000
    if netstat -tuln 2>/dev/null | grep -q ":3000 " || ss -tuln 2>/dev/null | grep -q ":3000 "; then
        log_warn "端口 3000 (Gitea) 已被占用"
    fi

    # 检查 Gitea 端口 2222
    if netstat -tuln 2>/dev/null | grep -q ":2222 " || ss -tuln 2>/dev/null | grep -q ":2222 "; then
        log_warn "端口 2222 (Gitea) 已被占用"
    fi

    log_success "端口检查完成"
}

# 显示帮助信息
show_help() {
    echo "Gitea 一体化部署脚本"
    echo ""
    echo "用法:"
    echo "  $0                      完整部署（推荐）"
    echo "  $0 --init              仅初始化环境"
    echo "  $0 --cleanup           清理其他项目目录"
    echo "  $0 --help              显示帮助信息"
    echo ""
    echo "功能说明:"
    echo "  默认模式    : 检查环境 -> 可选清理 -> 初始化 -> 部署服务"
    echo "  --init     : 仅创建目录、设置权限、检查端口（含可选清理）"
    echo "  --cleanup  : 仅清理上级目录中除当前目录外的所有文件"
    echo ""
    echo "特性:"
    echo "  • 自动生成 Runner 注册令牌"
    echo "  • 智能配置检查和部署"
    echo "  • 支持清理其他项目目录"
    echo "  • 健康检查和服务依赖管理"
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

    log_success "Gitea 项目环境初始化完成！"
    echo ""
    echo "🚀 接下来的步骤："
    echo "1. 快速部署: ./bootstrap.sh"
    echo "2. 或手动启动: docker compose up -d"
    echo "3. 查看日志: docker compose logs -f"
    echo "4. 停止服务: docker compose down"
    echo ""
    echo "🌐 服务端口："
    echo "- Gitea: http://localhost:3000"
    echo "- Gitea: http://localhost:2222"
    echo ""
}

# 生成随机令牌
generate_runner_token() {
    if command -v openssl &> /dev/null; then
        openssl rand -hex 24
    else
        # 如果没有openssl，使用date和随机数生成
        echo "$(date +%s)$(shuf -i 1000-9999 -n 1)" | sha256sum | cut -c1-48
    fi
}

# 创建.env文件
create_env_file() {
    if [[ ! -f .env ]]; then
        log_info "创建环境配置文件..."
        cp .env.example .env

        # 自动生成runner令牌
        log_info "自动生成 Runner 注册令牌..."
        GENERATED_TOKEN=$(generate_runner_token)

        # 替换.env文件中的令牌
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/your_generated_token_here/$GENERATED_TOKEN/" .env
        else
            # Linux
            sed -i "s/your_generated_token_here/$GENERATED_TOKEN/" .env
        fi

        log_success "环境配置文件创建完成，已自动生成 Runner 令牌"
        log_info "生成的令牌: $GENERATED_TOKEN"
    else
        log_success ".env 文件已存在"
    fi
}

# 检查Act-Runner配置
check_act_runner_config() {
    log_info "检查Act-Runner配置..."

    if [[ -f .env ]]; then
        source .env

        # 优先检查全局令牌（推荐方式）
        if [[ -n "${GITEA_RUNNER_REGISTRATION_TOKEN:-}" ]] && [[ "${GITEA_RUNNER_REGISTRATION_TOKEN}" != "your_generated_token_here" ]]; then
            log_success "使用全局 Runner 注册令牌（推荐方式）"
            return 0
        # 检查手动令牌（兼容方式）
        elif [[ -n "${ACT_RUNNER_TOKEN:-}" ]] && [[ "${ACT_RUNNER_TOKEN}" != "your_registration_token_here" ]]; then
            log_success "使用手动 Runner 注册令牌"
            return 0
        else
            log_warn "Runner 注册令牌未配置或使用默认值"
            log_info "当前配置使用自动生成的全局令牌，无需手动获取"
            return 0
        fi
    else
        log_warn ".env 文件不存在，请先创建"
        return 1
    fi
}

# 部署服务
deploy_services() {
    log_info "开始部署服务..."

    # 检查环境文件
    create_env_file

    # 首先启动基础服务
    log_info "启动 Gitea 和 PostgreSQL..."
    docker compose up -d postgres gitea

    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10

    # 检查Act-Runner配置
    if check_act_runner_config; then
        log_info "启动 Act-Runner..."
        docker compose up -d act-runner
    else
        log_warn "跳过 Act-Runner 启动，请配置后手动启动"
    fi

    # 显示服务状态
    log_info "服务状态："
    docker compose ps

    log_success "部署完成！"
    echo ""
    echo "🌐 访问地址："
    echo "  - Gitea: http://localhost:3000"
    echo "  - PostgreSQL: localhost:5432"
    echo ""
    echo "📝 下一步："
    echo "  1. 访问 Gitea 完成初始设置"
    echo "  2. 配置 Act-Runner 注册令牌（如果尚未配置）"
    echo "  3. 查看日志: docker compose logs -f"
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
            log_info "开始 Gitea 完整部署流程..."

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

            # 执行部署步骤
            create_directories
            set_permissions
            check_ports
            deploy_services
            ;;
        *)
            log_error "未知参数: $1"
            echo "使用 $0 --help 查看帮助信息"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
