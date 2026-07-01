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
./bootstrap.sh
```

首次运行会自动创建 `.env`、目录、密码（写入 `data/.credentials`）。重复运行安全：拉取镜像、滚动更新、自动注册/修复 Runner、加载 HTTPS 证书，**不删 data/**。

首次启动约 3-5 分钟：

```bash
docker compose ps
docker compose logs -f gitlab
```

访问 https://gitlab.devops.com（demo 自签证书，需在本机 `hosts` 添加 `127.0.0.1 gitlab.devops.com`），使用 `root` + `data/.credentials` 中的 `GITLAB_ROOT_PASSWORD` 登录。

## 日常运维

所有数据在 `./data/`。**只需 `./bootstrap.sh`**（或日常 `docker compose up -d` / `down`）。

| 场景 | 命令 |
|------|------|
| 部署 / 升级 / 换证书 / 重复更新 | `./bootstrap.sh` |
| 日常启停 | `docker compose up -d` / `down` |

注意：不要删 `data/` 或重生成已有环境的 `.env`。

## GitLab Runner

`./bootstrap.sh` 自动处理 Runner 注册；已有 `config.toml` 则跳过。

重新注册 Runner：删除 `data/gitlab-runner/config/config.toml` 后再跑 `./bootstrap.sh`。

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

启用后 `./bootstrap.sh`。**更换证书**：覆盖 `certs/` 内文件后再跑 `./bootstrap.sh`。

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
├── certs/                 # gitlab.devops.com.crt + .key
└── data/
    ├── postgresql/
    ├── redis-cache/
    ├── redis-persistent/
    ├── redis-sessions/
    ├── gitlab/{config,log,data,backups}/
    └── gitlab-runner/config/
```
