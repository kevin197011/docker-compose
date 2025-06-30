#!/bin/bash

# Atlassian Confluence 一体化部署脚本
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

# 创建或更新.env文件
create_env_file() {
    log_info "创建/更新 .env 配置文件..."

    # 如果.env文件不存在，询问配置信息
    if [ ! -f .env ]; then
        echo ""
        read -p "请输入Confluence域名 (默认: wiki.devops.io): " confluence_domain
        confluence_domain=${confluence_domain:-wiki.devops.io}

        # 提取域名主体部分（去掉前缀）
        domain_base=$(echo "$confluence_domain" | sed 's/^[^.]*\.//')

        # 创建.env文件
        cat > .env << EOF
# Confluence Configuration
CONFLUENCE_DOMAIN=${confluence_domain}

# Database Configuration
MYSQL_DATABASE=confluence
MYSQL_ROOT_PASSWORD=123456
MYSQL_USER=confluence
MYSQL_PASSWORD=123456

# Time Zone
TZ=Asia/Shanghai

# Nginx SSL Configuration
SSL_CERTIFICATE=${domain_base}.crt
SSL_CERTIFICATE_KEY=${domain_base}.key
EOF
        log_success ".env 配置文件创建完成"
    else
        log_warn "检测到已存在的 .env 文件"
        echo ""
        read -p "是否要重新配置? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 备份原有的.env文件
            cp .env .env.backup
            log_info "已备份原有配置到 .env.backup"

            # 重新配置
            read -p "请输入Confluence域名 (默认: wiki.devops.io): " confluence_domain
            confluence_domain=${confluence_domain:-wiki.devops.io}

            # 提取域名主体部分（去掉前缀）
            domain_base=$(echo "$confluence_domain" | sed 's/^[^.]*\.//')

            # 更新.env文件
            cat > .env << EOF
# Confluence Configuration
CONFLUENCE_DOMAIN=${confluence_domain}

# Database Configuration
MYSQL_DATABASE=confluence
MYSQL_ROOT_PASSWORD=123456
MYSQL_USER=confluence
MYSQL_PASSWORD=123456

# Time Zone
TZ=Asia/Shanghai

# Nginx SSL Configuration
SSL_CERTIFICATE=${domain_base}.crt
SSL_CERTIFICATE_KEY=${domain_base}.key
EOF
            log_success ".env 配置文件更新完成"
        else
            log_info "保持现有 .env 配置不变"
        fi
    fi
}

# 创建基本目录结构
create_directories() {
    log_info "创建目录结构..."

    # 根据项目需要创建目录
    mkdir -p data logs config ssl

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

    # 检查 Atlassian Confluence 端口 8090
    if netstat -tuln 2>/dev/null | grep -q ":8090 " || ss -tuln 2>/dev/null | grep -q ":8090 "; then
        log_warn "端口 8090 (Atlassian Confluence) 已被占用"
    fi

    log_success "端口检查完成"
}

# 显示帮助信息
show_help() {
    echo "Atlassian Confluence 一体化部署脚本"
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
}

# 从模板生成配置文件
generate_config_files() {
    log_info "从模板生成配置文件..."

    # 确保.env文件存在
    if [ ! -f .env ]; then
        log_error "未找到.env文件，请先运行初始化"
        exit 1
    fi

    # 加载环境变量
    set -a
    source .env
    set +a

    # 生成nginx配置
    log_info "生成 nginx.conf..."
    if [ -f templates/nginx.conf.tmpl ]; then
        envsubst '${CONFLUENCE_DOMAIN} ${SSL_CERTIFICATE} ${SSL_CERTIFICATE_KEY}' < templates/nginx.conf.tmpl > nginx.conf
        log_success "nginx.conf 生成完成"
    else
        log_error "未找到 nginx.conf.tmpl 模板文件"
    fi

    # 生成server.xml
    log_info "生成 server.xml..."
    if [ -f templates/server.xml.tmpl ]; then
        envsubst '${CONFLUENCE_DOMAIN}' < templates/server.xml.tmpl > server.xml
        log_success "server.xml 生成完成"
    else
        log_error "未找到 server.xml.tmpl 模板文件"
    fi
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
    create_env_file
    generate_config_files
    set_permissions
    check_ports

    log_success "Atlassian Confluence 项目环境初始化完成！"
    echo ""
    echo "🚀 接下来的步骤："
    echo "1. 快速部署: ./bootstrap.sh"
    echo "2. 或手动启动: docker compose up -d"
    echo "3. 查看日志: docker compose logs -f"
    echo "4. 停止服务: docker compose down"
    echo ""
    echo "🌐 服务端口："
    echo "- Atlassian Confluence: http://localhost:8090"
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

    log_info "开始 Atlassian Confluence 一体化部署..."

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
    create_env_file
    generate_config_files
    set_permissions
    check_ports

    # 启动服务
    log_info "启动服务..."
    docker compose up -d

    # 等待服务启动
    log_info "等待服务启动完成..."
    sleep 10

    # 显示访问信息
    echo ""
    log_success "Atlassian Confluence 部署完成！"
    echo ""
    echo "🌐 访问地址:"
    echo "  Atlassian Confluence: http://localhost:8090"
    echo ""
    echo "📊 查看服务状态: docker compose ps"
    echo "📋 查看日志: docker compose logs -f"
    echo ""
}

# 运行主函数
main "$@"
