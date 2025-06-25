#!/bin/bash

# JumpServer Docker Compose 初始化脚本
# Author: Docker Compose JumpServer Setup
# Description: 自动创建目录结构和设置必要的权限

set -e

# 锁文件路径
LOCK_FILE=".jumpserver_initialized"

# 清理其他项目目录函数
cleanup_other_directories() {
    log_info "清理其他项目目录..."

    # 当前目录名
    current_dir=$(basename "$(pwd)")

    # 切换到上级目录
    cd ../

    # 定义要保留的项目目录列表
    preserve_dirs=(
        "airflow" "apisix" "confluence" "drone" "drone-gitea" "elk"
        "gaia-pipeline" "gitea" "gitlab" "gitness" "graylog" "harness"
        "jenkins" "jira" "jumpserver" "mariadb" "minio" "mysql" "n8n"
        "prometheus" "rabbitmq" "redis" "sonarqube" "tick" "wikijs"
        "wireguard" "yearning"
    )

    # 构建find命令的排除条件
    find_cmd="find . -maxdepth 1 ! -name '.'"
    for dir in "${preserve_dirs[@]}"; do
        find_cmd="$find_cmd ! -name '$dir'"
    done
    find_cmd="$find_cmd -exec rm -rf {} +"

    # 显示将要执行的命令
    log_info "将执行清理命令: $find_cmd"

    # 询问用户确认
    echo ""
    log_warn "此操作将删除以下目录之外的所有文件和目录:"
    printf "%s " "${preserve_dirs[@]}"
    echo ""
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

# 检查是否已经初始化
check_lock_file() {
    if [ -f "$LOCK_FILE" ]; then
        log_warn "检测到锁文件 $LOCK_FILE，JumpServer 环境已经初始化过"
        echo ""
        echo "如果需要重新初始化，请："
        echo "1. 停止现有服务: docker compose down"
        echo "2. 删除锁文件: rm $LOCK_FILE"
        echo "3. 重新运行初始化脚本: ./init.sh"
        echo ""
        log_info "如果只需要重新生成密钥，请使用: ./init.sh --regenerate-secrets"
        exit 0
    fi
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

# 生成随机密钥并自动应用到配置文件
generate_and_apply_secrets() {
    log_info "生成安全密钥并自动应用到配置文件..."

        # 生成随机密钥（避免包含特殊字符）
    SECRET_KEY=$(openssl rand -base64 32 | tr -d '\n' | tr '/' '_' | tr '+' '-')
    BOOTSTRAP_TOKEN=$(openssl rand -hex 16)
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 16 | tr -d '\n' | tr '/' '_' | tr '+' '-')
    MYSQL_PASSWORD=$(openssl rand -base64 16 | tr -d '\n' | tr '/' '_' | tr '+' '-')
    REDIS_PASSWORD=$(openssl rand -base64 16 | tr -d '\n' | tr '/' '_' | tr '+' '-')

    log_info "生成的密钥信息："
    echo "SECRET_KEY: $SECRET_KEY"
    echo "BOOTSTRAP_TOKEN: $BOOTSTRAP_TOKEN"
    echo "MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD"
    echo "MYSQL_PASSWORD: $MYSQL_PASSWORD"
    echo "REDIS_PASSWORD: $REDIS_PASSWORD"
    echo ""

    # 更新 compose.yml 文件 (使用 | 作为分隔符避免 / 字符冲突)
    log_info "更新 compose.yml 文件中的密钥..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|SECRET_KEY: \".*\"|SECRET_KEY: \"$SECRET_KEY\"|" compose.yml
        sed -i '' "s|BOOTSTRAP_TOKEN: \".*\"|BOOTSTRAP_TOKEN: \"$BOOTSTRAP_TOKEN\"|" compose.yml
        sed -i '' "s|MYSQL_ROOT_PASSWORD: .*|MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD|" compose.yml
        sed -i '' "s|MYSQL_PASSWORD: .*|MYSQL_PASSWORD: $MYSQL_PASSWORD|" compose.yml
        sed -i '' "s|DB_PASSWORD: \".*\"|DB_PASSWORD: \"$MYSQL_PASSWORD\"|" compose.yml
        sed -i '' "s|REDIS_PASSWORD: \".*\"|REDIS_PASSWORD: \"$REDIS_PASSWORD\"|" compose.yml
        sed -i '' "s|--requirepass .*|--requirepass $REDIS_PASSWORD|" compose.yml
    else
        # Linux
        sed -i "s|SECRET_KEY: \".*\"|SECRET_KEY: \"$SECRET_KEY\"|" compose.yml
        sed -i "s|BOOTSTRAP_TOKEN: \".*\"|BOOTSTRAP_TOKEN: \"$BOOTSTRAP_TOKEN\"|" compose.yml
        sed -i "s|MYSQL_ROOT_PASSWORD: .*|MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD|" compose.yml
        sed -i "s|MYSQL_PASSWORD: .*|MYSQL_PASSWORD: $MYSQL_PASSWORD|" compose.yml
        sed -i "s|DB_PASSWORD: \".*\"|DB_PASSWORD: \"$MYSQL_PASSWORD\"|" compose.yml
        sed -i "s|REDIS_PASSWORD: \".*\"|REDIS_PASSWORD: \"$REDIS_PASSWORD\"|" compose.yml
        sed -i "s|--requirepass .*|--requirepass $REDIS_PASSWORD|" compose.yml
    fi

    # 更新 Redis 配置文件
    log_info "更新 Redis 配置文件中的密码..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^requirepass .*|requirepass $REDIS_PASSWORD|" config/redis/redis.conf
    else
        sed -i "s|^requirepass .*|requirepass $REDIS_PASSWORD|" config/redis/redis.conf
    fi

    # 保存密钥到文件
    cat > .jumpserver_secrets << EOF
# JumpServer 生成的密钥信息
# 生成时间: $(date)

SECRET_KEY=$SECRET_KEY
BOOTSTRAP_TOKEN=$BOOTSTRAP_TOKEN
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PASSWORD=$MYSQL_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
EOF

    log_success "密钥已成功生成并应用到配置文件"
    log_info "密钥信息已保存到 .jumpserver_secrets 文件中"
}

# 仅重新生成密钥（用于 --regenerate-secrets 选项）
regenerate_secrets_only() {
    log_info "重新生成密钥..."

    if [ ! -f "compose.yml" ]; then
        log_error "compose.yml 文件不存在，请先运行完整初始化"
        exit 1
    fi

    generate_and_apply_secrets
    log_success "密钥重新生成完成！"
    exit 0
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



# 创建锁文件
create_lock_file() {
    cat > "$LOCK_FILE" << EOF
# JumpServer 初始化锁文件
# 创建时间: $(date)
# 该文件表示 JumpServer 环境已经初始化完成
# 删除此文件可以重新运行初始化脚本

INITIALIZED=true
INIT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    log_info "创建锁文件: $LOCK_FILE"
}

# 显示使用说明
show_usage() {
    log_success "JumpServer 环境初始化完成！"
    echo ""
    echo "🚀 接下来的步骤："
    echo "1. 启动服务: docker compose up -d"
    echo "2. 查看日志: docker compose logs -f"
    echo "3. 访问管理界面: http://localhost"
    echo "4. 默认管理员账号: admin/admin (请立即修改密码)"
    echo ""
    echo "📁 重要文件："
    echo "- 密钥信息: .jumpserver_secrets"
    echo "- 锁文件: $LOCK_FILE"
    echo "- 配置文件: compose.yml"
    echo ""
    echo "🔧 其他命令："
    echo "- 重新生成密钥: ./init.sh --regenerate-secrets"
    echo "- 重新初始化: rm $LOCK_FILE && ./init.sh"
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
        --regenerate-secrets)
            regenerate_secrets_only
            ;;
        --help|-h)
            echo "JumpServer 初始化脚本"
            echo ""
            echo "用法:"
            echo "  $0                      完整初始化"
            echo "  $0 --cleanup            清理其他项目目录"
            echo "  $0 --regenerate-secrets 仅重新生成密钥"
            echo "  $0 --help              显示帮助信息"
            echo ""
            echo "清理功能说明:"
            echo "  --cleanup 选项会清理上级目录中除了预定义项目目录之外的所有文件和目录"
            echo "  保留的项目目录包括: airflow, apisix, confluence, drone, drone-gitea,"
            echo "                    elk, gaia-pipeline, gitea, gitlab, gitness, graylog,"
            echo "                    harness, jenkins, jira, jumpserver, mariadb, minio,"
            echo "                    mysql, n8n, prometheus, rabbitmq, redis, sonarqube,"
            echo "                    tick, wikijs, wireguard, yearning"
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

    log_info "开始初始化 JumpServer 环境..."

    # 询问是否需要先清理其他目录
    echo ""
    read -p "是否需要先清理其他项目目录? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_other_directories
        echo ""
    fi

    # 检查锁文件
    check_lock_file

    # 执行初始化步骤
    check_docker
    create_directories
    set_permissions
    check_ports
    generate_and_apply_secrets
    create_lock_file
    show_usage

    log_success "初始化脚本执行完成！"
}

# 运行主函数
main "$@"