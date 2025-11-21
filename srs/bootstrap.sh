#!/bin/bash

# SRS 一体化部署脚本
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

# 创建 SRS 目录结构
create_directories() {
    log_info "创建 SRS 目录结构..."

    # 创建 SRS 配置和数据目录
    SRS_DIR="$HOME/srs6"
    mkdir -p "$SRS_DIR/conf"
    mkdir -p "$SRS_DIR/objs"

    log_success "目录结构创建完成: $SRS_DIR"

    # 检查配置文件是否存在
    if [[ ! -f "$SRS_DIR/conf/srs.conf" ]]; then
        log_warn "配置文件 $SRS_DIR/conf/srs.conf 不存在"
        log_info "可以从 SRS 官方仓库获取默认配置文件"
        log_info "或访问: https://github.com/ossrs/srs/tree/develop/trunk/conf"
    else
        log_success "配置文件已存在: $SRS_DIR/conf/srs.conf"
    fi
}

# 设置目录权限
set_permissions() {
    log_info "设置目录权限..."

    SRS_DIR="$HOME/srs6"
    if [[ -d "$SRS_DIR" ]]; then
        chmod -R 755 "$SRS_DIR" 2>/dev/null || true
    fi

    # 设置脚本执行权限
    chmod +x bootstrap.sh 2>/dev/null || true

    log_success "权限设置完成"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."

    ports=(1935 1985 8080 8000 10080)
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
            log_warn "端口 ${port} 已被占用"
        fi
    done

    log_success "端口检查完成"
}

# 显示帮助信息
show_help() {
    echo "SRS 一体化部署脚本"
    echo ""
    echo "用法:"
    echo "  $0                      完整部署（推荐）"
    echo "  $0 --init              仅初始化环境"
    echo "  $0 --help              显示帮助信息"
    echo ""
    echo "功能说明:"
    echo "  默认模式    : 检查环境 -> 初始化 -> 部署服务"
    echo "  --init     : 仅创建目录、设置权限、检查端口"
    echo ""
    echo "特性:"
    echo "  • 自动创建 SRS 配置目录"
    echo "  • 智能配置检查和部署"
    echo "  • 健康检查和服务依赖管理"
    echo ""
}

# 仅初始化环境
init_only() {
    log_info "开始初始化项目环境..."

    # 检查系统要求
    check_requirements

    # 执行初始化步骤
    create_directories
    set_permissions
    check_ports

    log_success "SRS 项目环境初始化完成！"
    echo ""
    echo "🚀 接下来的步骤："
    echo "1. 确保配置文件存在: ~/srs6/conf/srs.conf"
    echo "2. 快速部署: ./bootstrap.sh"
    echo "3. 或手动启动: docker compose up -d"
    echo "4. 查看日志: docker compose logs -f"
    echo "5. 停止服务: docker compose down"
    echo ""
    echo "🌐 服务端口："
    echo "- RTMP: rtmp://localhost:1935"
    echo "- HTTP API: http://localhost:1985"
    echo "- HTTP: http://localhost:8080"
    echo "- UDP: 8000, 10080"
    echo ""
}

# 部署服务
deploy_services() {
    log_info "开始部署服务..."

    # 检查配置文件
    SRS_DIR="$HOME/srs6"
    if [[ ! -f "$SRS_DIR/conf/srs.conf" ]]; then
        log_warn "配置文件 $SRS_DIR/conf/srs.conf 不存在"
        log_info "正在创建基本配置文件..."

        # 创建基本配置文件
        cat > "$SRS_DIR/conf/srs.conf" << 'EOF'
listen              1935;
max_connections     1000;
srs_log_tank        file;
srs_log_file        ./objs/srs.log;

http_api {
    enabled         on;
    listen          1985;
}

http_server {
    enabled         on;
    listen          8080;
    dir             ./objs/nginx/html;
}

vhost __defaultVhost__ {
    hls {
        enabled         on;
        hls_path        ./objs/nginx/html;
        hls_fragment   10;
        hls_window     60;
    }

    http_remux {
        enabled     on;
        mount       [vhost]/[app]/[stream].flv;
    }
}
EOF
        log_success "已创建基本配置文件: $SRS_DIR/conf/srs.conf"
    fi

    # 启动服务
    log_info "启动 SRS 服务..."
    docker compose up -d

    # 显示服务状态
    log_info "服务状态："
    docker compose ps

    log_success "部署完成！"
    echo ""
    echo "🌐 访问地址："
    echo "  - RTMP 推流: rtmp://localhost:1935/live/stream"
    echo "  - HTTP API: http://localhost:1985/api/v1/"
    echo "  - HLS 播放: http://localhost:8080/live/stream.m3u8"
    echo "  - HTTP-FLV 播放: http://localhost:8080/live/stream.flv"
    echo ""
    echo "📝 下一步："
    echo "  1. 使用 FFmpeg 或 OBS 推流到 rtmp://localhost:1935/live/stream"
    echo "  2. 查看日志: docker compose logs -f"
    echo "  3. 查看 API: curl http://localhost:1985/api/v1/versions"
}

# 主函数
main() {
    # 处理命令行参数
    case "${1:-}" in
        --init)
            init_only
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # 默认行为：完整部署
            log_info "开始 SRS 完整部署流程..."

            # 检查系统要求
            check_requirements

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

