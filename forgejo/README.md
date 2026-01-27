# Forgejo Docker Compose 配置

生产级 Forgejo 部署配置，包含 PostgreSQL、Redis 和 Runner。

## 功能特性

- ✅ PostgreSQL 16 数据库（生产级配置）
- ✅ Redis 7 缓存和会话存储
- ✅ Forgejo Actions 支持
- ✅ 两步部署流程（先启动服务，后注册 Runner）
- ✅ 健康检查和依赖管理
- ✅ 数据持久化

## 快速开始

### 第一步：启动 Forgejo 服务

```bash
# 1. 准备环境变量
cp .env.example .env
# 编辑 .env 文件，设置数据库密码

# 2. 启动基础服务（PostgreSQL、Redis、Forgejo）
docker compose up -d

# 3. 等待服务就绪
docker compose ps
```

### 第二步：注册并启动 Runner

#### 方式 1：使用注册脚本（推荐）

```bash
# 1. 获取 Runner 注册令牌
# 方式 A: 从 Web 界面获取
# 访问 http://localhost:3000
# Site administration > Actions > Runners > Create new Runner（选择 Global）

# 方式 B: 使用 CLI 生成
docker exec forgejo forgejo forgejo-cli actions generate-runner-token

# 2. 将令牌添加到 .env 文件
# FORGEJO_RUNNER_REGISTRATION_TOKEN=你的令牌

# 3. 注册 Runner
./register-runner.sh

# 4. 启动 Runner 服务
./start-runner.sh
```

#### 方式 2：手动注册

```bash
# 1. 获取注册令牌（同上）

# 2. 手动注册 Runner
docker run --rm \
  --network forgejo_net \
  -v $(pwd)/data/runner:/data \
  -e FORGEJO_INSTANCE_URL=http://forgejo:3000 \
  -e FORGEJO_RUNNER_REGISTRATION_TOKEN=你的令牌 \
  code.forgejo.org/forgejo/runner:12 \
  register \
  --instance http://forgejo:3000 \
  --token 你的令牌 \
  --name forgejo-runner \
  --labels ubuntu-latest:docker://node:20-bookworm,ubuntu-22.04:docker://node:20-bookworm \
  --no-interactive

# 3. 启动 Runner 服务
docker compose up -d forgejo-runner
```

## 访问地址

- Web 界面: http://localhost:3000
- SSH 克隆: `ssh://git@localhost:2222/用户名/仓库名.git`

## 验证 Runner 状态

```bash
# 查看 Runner 日志
docker compose logs -f forgejo-runner

# 在 Forgejo Web 界面查看
# Site administration > Actions > Runners
```

## 配置说明

### 环境变量

- `FORGEJO_DB_PASSWORD`: PostgreSQL 数据库密码（必需）
- `FORGEJO_RUNNER_REGISTRATION_TOKEN`: Runner 注册令牌（注册时必需）
- `FORGEJO_INSTANCE_URL`: Forgejo 实例地址（默认: http://forgejo:3000）
- `FORGEJO_RUNNER_NAME`: Runner 名称（默认: forgejo-runner）
- `FORGEJO_RUNNER_LABELS`: Runner 标签（定义可用的运行环境）

### 数据目录

- `./data/forgejo`: Forgejo 主数据目录
- `./data/runner`: Runner 数据目录（包含 `.runner` 注册文件）
- `./data/postgres`: PostgreSQL 数据目录
- `./data/redis`: Redis 数据目录

## 常用命令

```bash
# 启动所有服务
docker compose up -d

# 仅启动基础服务（不包含 runner）
docker compose up -d postgres redis forgejo

# 注册 Runner
./register-runner.sh

# 启动 Runner
./start-runner.sh

# 停止 Runner
docker compose stop forgejo-runner

# 查看日志
docker compose logs -f forgejo-runner

# 重新注册 Runner（删除注册文件后重新注册）
rm data/runner/.runner
./register-runner.sh
```

## 参考文档

- [Forgejo Runner 安装指南](https://forgejo.org/docs/next/admin/actions/runner-installation/)
- [Forgejo Actions 文档](https://forgejo.org/docs/next/user/actions/)
