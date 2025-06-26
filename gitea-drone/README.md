# Gitea + Drone CI/CD

基于 Docker Compose 的现代化 Gitea + Drone CI/CD 环境，支持自动IP地址获取和一键部署。

## 特性

- **自动IP获取**: 智能检测并使用本机IP地址，无需手动配置
- **最新版本**: 使用最新稳定版本的 Gitea 和 Drone
- **健康检查**: 内置服务健康检查，确保服务正常启动
- **一键部署**: 简化的部署流程，几分钟内完成CI/CD环境搭建
- **完整集成**: Gitea + Drone + Runner 完整CI/CD解决方案

## 版本信息

| 服务 | 版本 | 说明 |
|------|------|------|
| Gitea | 1.21.5 | Git 仓库管理平台 |
| Drone | 2.23.0 | CI/CD 服务器 |
| Drone Runner | 1.8.3 | CI/CD 任务执行器 |

## 快速开始

### 一键部署

```bash
# 自动获取IP并启动所有服务（推荐）
./bootstrap.sh

# 或者仅初始化环境
./bootstrap.sh --init
```

### 手动部署（可选）

```bash
# 手动启动服务
docker compose up -d

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

## 服务访问

部署完成后，可通过以下地址访问：

- **Gitea**: http://your-ip:3000 (Git 仓库管理)
- **Drone**: http://your-ip:3001 (CI/CD 控制台)
- **Drone Runner**: http://your-ip:3002 (任务执行器状态)
- **Gitea SSH**: your-ip:2222 (Git SSH 访问)

> IP地址会在部署时自动检测并显示

## 配置流程

### 1. Gitea 初始化

1. 访问 Gitea Web 界面
2. 完成初始化设置（数据库、管理员账户等）
3. 创建第一个仓库

### 2. 配置 OAuth2 应用

1. 在 Gitea 中进入 **设置** → **应用** → **管理 OAuth2 应用程序**
2. 创建新的 OAuth2 应用：
   - **应用名称**: Drone
   - **重定向 URI**: `http://your-ip:3001/login`
3. 记录生成的 **Client ID** 和 **Client Secret**

### 3. 配置 Drone

1. 创建配置文件：
   ```bash
   cp config-example.sh config.sh
   ```

2. 编辑配置文件，填写获取的 OAuth2 凭据：
   ```bash
   # 编辑 config.sh 文件
   export DRONE_GITEA_CLIENT_ID="your-client-id"
   export DRONE_GITEA_CLIENT_SECRET="your-client-secret"
   ```

3. 加载配置并重新启动：
   ```bash
   source config.sh
   docker compose restart drone
   ```

### 4. 验证集成

1. 访问 Drone Web 界面
2. 使用 Gitea 账户登录
3. 同步仓库并启用 CI/CD

## 目录结构

```
gitea-drone/
├── compose.yml          # Docker Compose 配置
├── bootstrap.sh         # 一体化部署脚本
├── config-example.sh    # 配置示例文件
├── README.md           # 说明文档
└── data/               # 数据持久化目录
    ├── gitea/          # Gitea 数据
    └── drone/          # Drone 数据
```

## 常用命令

```bash
# 查看脚本帮助
./bootstrap.sh --help

# 仅初始化环境（不启动服务）
./bootstrap.sh --init

# 清理其他项目目录
./bootstrap.sh --cleanup

# 查看服务状态
docker compose ps

# 查看实时日志
docker compose logs -f

# 重启特定服务
docker compose restart gitea
docker compose restart drone

# 停止所有服务
docker compose down

# 完全清理（包括数据）
docker compose down -v
rm -rf data/
```

## 故障排除

### 1. 服务无法启动

```bash
# 检查端口占用
netstat -tuln | grep -E ":(3000|3001|3002|2222)"

# 查看详细日志
docker compose logs gitea
docker compose logs drone
```

### 2. IP地址获取失败

```bash
# 手动设置IP地址
export IP_ADDRESS="your-manual-ip"
./bootstrap.sh
```

### 3. OAuth2 配置问题

- 确保重定向URI正确设置
- 检查Client ID和Secret是否正确
- 验证Drone服务是否可以访问Gitea

### 4. 权限问题

```bash
# 修复数据目录权限
sudo chown -R 1000:1000 data/
chmod -R 755 data/
```

## 高级配置

### 自定义版本

```bash
# 设置自定义版本
export GITEA_VERSION="1.21.5"
export DRONE_VERSION="2.23.0"
export DRONE_RUNNER_VERSION="1.8.3"
./bootstrap.sh
```

### SSL/TLS 配置

如需启用HTTPS，请修改 `compose.yml` 中的相关配置并挂载SSL证书。

### 外部数据库

默认使用SQLite，如需使用MySQL/PostgreSQL，请修改相应的环境变量。

## 清理命令

```bash
# 停止并删除所有服务和数据
find . -maxdepth 1 ! -name '.' ! -name 'gitea-drone' -exec rm -rf {} +
```

## 技术支持

- [Gitea 官方文档](https://docs.gitea.io/)
- [Drone 官方文档](https://docs.drone.io/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
