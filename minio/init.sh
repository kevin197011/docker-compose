#!/bin/bash

# Docker Compose 项目初始化脚本
# Author: Docker Compose Setup
# Description: 自动创建目录结构、设置权限和清理其他项目目录

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
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

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! command -v docker compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi

    log_info "Docker 和 Docker Compose 检查通过"
}

# 创建基本目录结构
create_directories() {
    log_info "创建目录结构..."

    # 根据项目需要创建目录
    mkdir -p data logs config

    log_info "目录结构创建完成"
}

# 设置目录权限
set_permissions() {
    log_info "设置目录权限..."

    # 设置基本权限
    chmod -R 755 data/ 2>/dev/null || true
    chmod -R 755 logs/ 2>/dev/null || true
    chmod -R 755 config/ 2>/dev/null || true

    # 设置脚本执行权限
    chmod +x init.sh 2>/dev/null || true

    log_info "权限设置完成"
}

# 检查端口占用
check_ports() {
    log_info "检查基本端口占用情况..."
    
    # 这里可以根据具体项目添加端口检查
    # 示例：检查80端口
    if netstat -tuln 2>/dev/null | grep -q ":80 " || ss -tuln 2>/dev/null | grep -q ":80 "; then
        log_warn "端口 80 已被占用"
    fi
    
    log_info "端口检查完成"
}

# 显示使用说明
show_usage() {
    log_success "项目环境初始化完成！"
    echo ""
    echo "🚀 接下来的步骤："
    echo "1. 启动服务: docker compose up -d"
    echo "2. 查看日志: docker compose logs -f"
    echo "3. 停止服务: docker compose down"
    echo ""
    echo "🔧 其他命令："
    echo "- 清理其他项目目录: ./init.sh --cleanup"
    echo "- 查看帮助: ./init.sh --help"
    echo ""
    echo "📖 更多信息请查看 README.md 文件"
}

# 主函数
main() {
    # 处理命令行参数
    case "${1:-}" in
        --cleanup)
            cleanup_other_directories
            exit 0
            ;;
        --help|-h)
            echo "Docker Compose 项目初始化脚本"
            echo ""
            echo "用法:"
            echo "  $0                      完整初始化"
            echo "  $0 --cleanup            清理其他项目目录"
            echo "  $0 --help              显示帮助信息"
            echo ""
            echo "清理功能说明:"
            echo "  --cleanup 选项会清理上级目录中除了当前目录之外的所有文件和目录"
            echo "  当前目录 '$(basename "$(pwd)")' 将被保留"
            exit 0
            ;;
        "")
            # 默认行为：完整初始化
            ;;
        *)
            log_error "未知参数: $1"
            echo "使用 $0 --help 查看帮助信息"
            exit 1
            ;;
    esac

    log_info "开始初始化项目环境..."

    # 询问是否需要先清理其他目录
    echo ""
    read -p "是否需要先清理其他项目目录? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_other_directories
        echo ""
    fi

    # 执行初始化步骤
    check_docker
    create_directories
    set_permissions
    check_ports
    show_usage

    log_success "初始化脚本执行完成！"
}

# 运行主函数
main "$@"
