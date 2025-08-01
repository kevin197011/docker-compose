# Gitea with Act-Runner Docker Compose 部署

## 📖 项目简介

轻量级的 Git 服务，类似于 GitHub 的自托管解决方案，集成了 Gitea Actions 和 Act-Runner 支持，提供完整的 CI/CD 功能

## ✨ 功能特性

- 🚀 一键部署，开箱即用
- 🔧 自动环境检查和初始化
- 📊 健康检查和服务监控
- 🛠️ 完整的数据持久化
- 🔄 支持服务重启和升级
- 📋 详细的日志记录
- ⚡ 集成 Gitea Actions 和 Act-Runner
- 🔧 自动注册 Runner 到 Gitea 实例
- 🐳 支持 Docker 容器和主机模式执行

## 🚀 快速开始

### 方式一：一键部署（推荐）

```bash
# 克隆项目
git clone <repository-url>
cd gitea

# 一键部署
./bootstrap.sh
```

### 方式二：分步部署

```bash
# 1. 初始化环境
./bootstrap.sh --init

# 2. 启动服务
docker compose up -d

# 3. 查看状态
docker compose ps
```

### 方式三：清理其他项目

在多项目环境中，您可能需要清理其他项目目录以节省空间：

```bash
# 仅清理其他项目目录
./bootstrap.sh --cleanup

# 查看帮助信息
./bootstrap.sh --help
```

**注意**：清理操作会删除上级目录中除当前gitea目录外的所有文件和目录，请谨慎操作。

## 📋 系统要求

- Docker Engine 20.10+
- Docker Compose 2.0+
- 系统内存: 建议 2GB+
- 磁盘空间: 建议 10GB+

## 🌐 服务端口

- **3000**: Gitea Web 服务端口
- **2222**: Gitea SSH 服务端口（已配置环境变量）
- **5432**: PostgreSQL 数据库端口


## 🔧 配置说明

### 目录结构

```
gitea/
├── bootstrap.sh          # 一体化部署脚本
├── compose.yml           # Docker Compose 配置
├── README.md            # 项目文档
├── .env.example         # 环境变量示例文件
├── data/               # 数据目录
│   ├── gitea/          # Gitea 数据
│   ├── postgres/       # PostgreSQL 数据
│   └── act-runner/     # Act-Runner 数据
├── logs/               # 日志目录
└── config/             # 配置目录
    └── act-runner      # Act-Runner 配置文件
```

### 环境变量

复制 `.env.example` 到 `.env` 并配置以下变量：

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑环境变量
vi .env
```

主要环境变量：
- `GITEA_RUNNER_REGISTRATION_TOKEN`: 全局 Runner 注册令牌（推荐，自动生成）
- `GITEA_INSTANCE_URL`: Gitea 实例访问地址（可动态配置）
- `ACT_RUNNER_TOKEN`: 手动 Runner 注册令牌（兼容旧方式）
- `ACT_RUNNER_NAME`: Runner 名称（可选）
- `ACT_RUNNER_LABELS`: Runner 标签（可选）

#### 动态配置 Gitea 实例地址

`GITEA_INSTANCE_URL` 环境变量控制 Act-Runner 如何连接到 Gitea 实例：

```bash
# 内部访问（默认，适用于容器间通信）
GITEA_INSTANCE_URL=http://gitea:3000

# 外部IP访问（用于CI/CD或外部Runner）
GITEA_INSTANCE_URL=http://192.168.1.19:3000

# 域名访问
GITEA_INSTANCE_URL=http://gitea.yourdomain.com
```

**自动获取IP启动**：

```bash
# 使用内部地址启动（默认）
./start.sh

# 自动获取外部IP并启动
USE_EXTERNAL_IP=true ./start.sh

# 指定端口
GITEA_PORT=3000 USE_EXTERNAL_IP=true ./start.sh
```

这对于解决 CI/CD 中的主机名解析问题特别有用。

### 预配置的Gitea设置

项目已预配置以下Gitea环境变量：
- `GITEA__server__SSH_PORT=2222`: SSH服务端口配置
- `GITEA__actions__ENABLED=true`: 启用Gitea Actions功能
- `GITEA__security__DISABLE_QUERY_AUTH_TOKEN=false`: 安全配置

### Act-Runner 配置方式

#### 方式一：自动生成令牌（推荐）

1. **一键部署**：
   ```bash
   ./bootstrap.sh
   ```
   脚本会自动：
   - 询问是否清理其他项目目录（可选）
   - 生成随机的全局注册令牌
   - 创建并配置 `.env` 文件
   - 启动所有服务（包括 Act-Runner）

2. **访问 Gitea 完成初始设置**：
   - 访问: http://localhost:3000
   - 完成 Gitea 初始设置
   - Act-Runner 会自动注册并显示在管理面板

#### 方式二：手动获取令牌（兼容方式）

1. **启动基础服务**：
   ```bash
   docker compose up -d postgres gitea
   ```

2. **访问 Gitea 并完成初始设置**：
   - 访问: http://localhost:3000
   - 完成 Gitea 初始设置

3. **获取 Runner 注册令牌**：
   - 进入管理面板: http://localhost:3000/-/admin/actions/runners
   - 复制注册令牌

4. **配置环境变量**：
   ```bash
   # 编辑 .env 文件，注释掉 GITEA_RUNNER_REGISTRATION_TOKEN
   # GITEA_RUNNER_REGISTRATION_TOKEN=...
   ACT_RUNNER_TOKEN=your_manual_token_here
   ```

5. **启动 Act-Runner**：
   ```bash
   docker compose up -d act-runner
   ```

### 手动生成注册令牌

如果您想要手动生成全局注册令牌，可以使用以下命令：

```bash
# 使用 openssl 生成随机令牌（推荐）
openssl rand -hex 24

# 或者使用 uuidgen
uuidgen | tr -d '-'

# 然后在 .env 文件中设置
GITEA_RUNNER_REGISTRATION_TOKEN=生成的令牌
```

## 📊 使用指南

### 启动服务

```bash
# 后台启动
docker compose up -d

# 前台启动（查看日志）
docker compose up
```

### 查看状态

```bash
# 查看服务状态
docker compose ps

# 查看服务日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f <service-name>
```

### 停止服务

```bash
# 停止服务
docker compose down

# 停止服务并删除数据卷
docker compose down -v
```

## 🔗 访问地址

服务启动后，可以通过以下地址访问：

- **Gitea Web**: http://localhost:3000
- **Gitea SSH**: ssh://git@localhost:2222
- **PostgreSQL**: localhost:5432

### Gitea Actions 使用

创建 `.gitea/workflows/ci.yml` 文件来定义工作流：

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          echo "Running tests..."
          # 添加你的测试命令
```


## 🛠️ 故障排除

### 常见问题

1. **端口冲突**
   - 检查端口是否被占用：`netstat -tulpn | grep <port>`
   - 修改 `compose.yml` 中的端口映射

2. **权限问题**
   - 确保当前用户有 Docker 权限：`sudo usermod -aG docker $USER`
   - 重新登录或重启系统

3. **内存不足**
   - 检查系统内存使用：`free -h`
   - 调整 Docker 内存限制

4. **磁盘空间不足**
   - 检查磁盘空间：`df -h`
   - 清理 Docker 镜像：`docker system prune -a`

### 日志查看

```bash
# 查看所有服务日志
docker compose logs

# 实时查看日志
docker compose logs -f

# 查看最近100行日志
docker compose logs --tail=100
```

## 🔄 升级指南

### 升级服务

```bash
# 1. 停止当前服务
docker compose down

# 2. 拉取最新镜像
docker compose pull

# 3. 重新启动
docker compose up -d
```

### 备份数据

```bash
# 备份数据目录
tar -czf backup-$(date +%Y%m%d).tar.gz data/

# 备份配置文件
cp compose.yml compose.yml.backup
```

## 📚 相关资源

- [官方文档](https://docs.docker.com/compose/)
- [Docker Hub]()
- [GitHub 仓库]()

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](../LICENSE) 文件了解详情。

## ⭐ Star History

如果这个项目对你有帮助，请给它一个星标！

---

**注意**: 首次部署时，某些服务可能需要额外的配置步骤，请参考具体服务的官方文档。

## 网络连接故障排除

### 问题：CI/CD 中无法解析 "gitea" 主机名

如果在 CI/CD 流水线中看到类似错误：
```
fatal: unable to access 'http://gitea:3000/root/repo/': Could not resolve host: gitea
```

#### 解决方案 1：使用外部可访问的 URL

将仓库的远程 URL 更改为外部可访问的地址：

```bash
# 使用主机 IP 地址
git remote set-url origin http://YOUR_HOST_IP:3000/username/repo

# 或使用配置的域名
git remote set-url origin http://gitea.yourdomain.com/username/repo
```

#### 解决方案 2：配置共享 Docker 网络

如果 CI/CD runner 也在 Docker 中运行，确保它们连接到相同的网络：

1. **创建共享网络**：
   ```bash
   docker network create shared_network
   ```

2. **修改 compose.yml 使用外部网络**：
   ```yaml
   networks:
     default:
       external: true
       name: shared_network
   ```

3. **启动其他 CI/CD 服务时连接到相同网络**：
   ```bash
   docker run --network shared_network your-ci-service
   ```

#### 解决方案 3：使用 host 网络模式

在 compose.yml 中添加网络模式：
```yaml
services:
  gitea:
    network_mode: "host"
    # 注意：使用 host 模式时需要移除 ports 映射
```

#### 解决方案 4：配置 DNS 解析

在 CI/CD runner 容器中添加 extra_hosts：
```yaml
services:
  ci-runner:
    extra_hosts:
      - "gitea:YOUR_HOST_IP"
```

### 验证网络连接

测试服务间的网络连接：
```bash
# 从 runner 容器内测试连接
docker exec gitea-act-runner wget -qO- http://gitea:3000/api/healthz

# 检查网络配置
docker network ls
docker network inspect gitea_gitea_net
```
