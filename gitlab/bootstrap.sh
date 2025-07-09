#!/bin/bash
set -e

# 彩色日志
log() { local c=$1; shift; echo -e "${c}$*\033[0m"; }
info() { log "\033[0;34m[INFO]" "$@"; }
success() { log "\033[0;32m[SUCCESS]" "$@"; }
warn() { log "\033[1;33m[WARN]" "$@"; }
error() { log "\033[0;31m[ERROR]" "$@"; }

# 检查依赖
check_env() {
  command -v docker &>/dev/null || { error "缺少 Docker"; exit 1; }
  command -v docker compose &>/dev/null || { error "缺少 Docker Compose"; exit 1; }
  success "依赖检查通过"
}

# 初始化目录和权限
init_dirs() {
  mkdir -p data logs config
  chmod -R 755 data logs config 2>/dev/null || true
  chmod +x bootstrap.sh 2>/dev/null || true
  success "目录和权限已就绪"
}

# 端口检查
check_ports() {
  for p in 80 443 22; do
    (netstat -tuln 2>/dev/null || ss -tuln 2>/dev/null) | grep -q ":$p " && warn "端口 $p 已被占用"
  done
  success "端口检查完成"
}

# 清理其他目录
cleanup() {
  local cur=$(basename "$PWD"); cd ..
  warn "将删除除 '$cur' 外的所有内容，是否继续? (y/N): "
  read -r yn; [[ $yn =~ ^[Yy]$ ]] && find . -maxdepth 1 ! -name '.' ! -name "$cur" -exec rm -rf {} + && success "清理完成" || info "已取消"
  cd "$cur"
}

# 帮助
show_help() {
  echo "用法: $0 [--init|--cleanup|--help]"
  echo "  --init     仅初始化环境"
  echo "  --cleanup  清理其他目录"
  echo "  --help     显示帮助"
}

# 初始化
init_only() {
  info "初始化环境..."
  check_env
  info "是否清理其他目录? (y/N): "; read -r yn; [[ $yn =~ ^[Yy]$ ]] && cleanup
  init_dirs
  check_ports
  success "初始化完成"
  echo -e "\n🚀 ./bootstrap.sh 部署 | docker compose up -d 启动 | logs/ 查看日志"
}

# 主流程
main() {
  case "$1" in
    --init) init_only; exit;;
    --cleanup) cleanup; exit;;
    --help|-h) show_help; exit;;
    "") ;;
    *) error "未知参数: $1"; show_help; exit 1;;
  esac
  info "开始部署..."
  check_env
  info "是否清理其他目录? (y/N): "; read -r yn; [[ $yn =~ ^[Yy]$ ]] && cleanup
  init_dirs
  check_ports
  info "启动服务..."
  docker compose up -d
  sleep 8
  success "GitLab 部署完成！"
  echo -e "\n🌐 访问: http://localhost | https://localhost\n📊 状态: docker compose ps | 日志: docker compose logs -f\n👤 首次访问请设置 root 密码"
}

main "$@"