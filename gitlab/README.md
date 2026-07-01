# GitLab Docker Compose（生产级）

GitLab CE + 外部 PostgreSQL 17 + 三实例 Redis 7 的高性能生产部署配置。

## 架构

| 组件 | 镜像 | 说明 |
|------|------|------|
| GitLab CE | `gitlab/gitlab-ce:18.11.6-ce.0` | Omnibus，禁用内置 PG/Redis |
| PostgreSQL | `postgres:17-alpine` | 独立数据库，生产级参数调优 |
| Redis Cache | `redis:7-alpine` | 缓存 + 仓库缓存（LRU，无持久化） |
| Redis Persistent | `redis:7-alpine` | 队列、共享状态、限流等（AOF） |
| Redis Sessions | `redis:7-alpine` | 会话存储（AOF） |
| GitLab Runner | `gitlab/gitlab-runner:alpine-v18.11.4` | 实例级全局 Runner，bootstrap 自动注册 |

## 硬件建议

| 团队规模 | 最低内存 | 推荐内存 | vCPU |
|----------|----------|----------|------|
| 1-5 人 | 8GB | 16GB | 4 |
| 5-20 人 | 16GB | 32GB | 8 |
| 20+ 人 | 32GB+ | 64GB+ | 16+ |

GitLab 官方建议 Docker 容器 `shm_size` ≥ 256MB（已配置）。

## 快速开始

```bash
cd gitlab

# 1. 初始化（自动生成 .env 与各组件密码）
./bootstrap.sh --init

# 2. 启动
./bootstrap.sh
# 或: docker compose up -d
```

密码在首次 `./bootstrap.sh --init` 时由 `openssl rand -hex 16` 自动生成，写入 `.env` 并备份到 `data/.credentials`（已在 `.gitignore` 的 `data/` 下）。

首次启动约 3-5 分钟。查看状态：

```bash
docker compose ps
docker compose logs -f gitlab
```

访问 https://gitlab.devops.com（demo 自签证书，需在本机 `hosts` 添加 `127.0.0.1 gitlab.devops.com`），使用 `root` + `data/.credentials` 中的 `GITLAB_ROOT_PASSWORD` 登录。

## 日常运维（不丢数据）

所有持久化数据在 `./data/`（PostgreSQL、Redis、GitLab 仓库、Runner 配置）。**重复执行 `./bootstrap.sh` 或 `docker compose up -d` 不会删除这些数据**。

| 场景 | 命令 |
|------|------|
| 日常启停 | `docker compose up -d` / `docker compose down` |
| 升级镜像 / 重复部署 | `./bootstrap.sh` |
| 更换 HTTPS 证书 | 覆盖 `certs/` 内文件 → `./bootstrap.sh --certs` |
| 仅初始化目录与密码 | `./bootstrap.sh --init`（仅首次） |

注意：

- **不要**删除 `data/` 或重新生成已有环境的 `.env`（密码与数据库绑定）
- **不要**使用 `docker compose down -v`（本栈虽用 bind mount，仍避免误操作习惯）
- 证书热更新用 `--certs`（`gitlab-ctl hup nginx`），无需重启整个 GitLab 容器

## GitLab Runner

`./bootstrap.sh` 首次会分步启动并注册 Runner；已有环境则直接 `compose up -d` 滚动更新。

日常启停直接用 `docker compose up -d` / `down` 即可（`config.toml` 持久化在 `data/gitlab-runner/config/`）。

重新注册：删除 `data/gitlab-runner/config/config.toml` 后执行 `./bootstrap.sh --register-runner`。

## HTTPS（Omnibus 手动证书）

证书由 GitLab 内置 Nginx 加载，默认 demo 文件：

| 文件 | 说明 |
|------|------|
| `certs/gitlab.devops.com.crt` | 证书 |
| `certs/gitlab.devops.com.key` | 私钥 |

`.env`（已预置 demo 域名）：

```env
GITLAB_URL=https://gitlab.devops.com
GITLAB_LISTEN_HTTPS=true
GITLAB_REDIRECT_HTTP_TO_HTTPS=true
GITLAB_SSL_CERT=gitlab.devops.com.crt
GITLAB_SSL_KEY=gitlab.devops.com.key
```

本机解析（`/etc/hosts`）：

```
127.0.0.1 gitlab.devops.com
```

启用后 `docker compose up -d`，等待 GitLab reconfigure。**更换证书**：覆盖 `certs/` 内文件后执行 `./bootstrap.sh --certs`（不重启数据库、不丢仓库数据）。

自定义文件名可改 `GITLAB_SSL_CERT`、`GITLAB_SSL_KEY`（容器内路径为 `/etc/gitlab/ssl/<文件名>`）。

## 生产注意事项

1. **版本锁定**：在 `.env` 中固定 `GITLAB_CE_VERSION`，升级前阅读 [GitLab Release Notes](https://about.gitlab.com/releases/)。
2. **密码**：由 bootstrap 自动生成（纯 hex，兼容 Redis URL）。查看：`cat data/.credentials`
3. **备份**：数据目录在 `./data/`；可用 `docker exec gitlab gitlab-backup create` 创建备份。
4. **调优**：按主机规格调整 `.env` 中 `GITLAB_PUMA_WORKERS`、`GITLAB_SIDEKIQ_CONCURRENCY` 及 PostgreSQL `command` 中的内存参数。

## 端口

| 服务 | 默认端口 |
|------|----------|
| HTTP | 80 |
| HTTPS | 443 |
| Git SSH | 2222 |

## 目录结构

```
gitlab/
├── compose.yml
├── .env.example
├── bootstrap.sh
├── register-runner.sh
├── certs/                 # gitlab.devops.com.crt + .key
└── data/
    ├── postgresql/
    ├── redis-cache/
    ├── redis-persistent/
    ├── redis-sessions/
    ├── gitlab/{config,log,data,backups}/
    └── gitlab-runner/config/
```
