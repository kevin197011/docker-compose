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

访问 `http://localhost:8000`（或 `.env` 中的 `GITLAB_URL`），使用 `root` + `data/.credentials` 中的 `GITLAB_ROOT_PASSWORD` 登录。

## GitLab Runner（全局实例 Runner）

`./bootstrap.sh` 会在 GitLab 就绪后自动执行 `register-runner.sh`：

- **类型**：`instance_type`（实例级 Runner，所有项目/群组可用）
- **无标签作业**：`run_untagged=true`，未指定 tag 的 CI 也能跑
- **标签**：默认 `docker,shared`（可在 `.env` 改 `GITLAB_RUNNER_TAG_LIST`）
- **执行器**：Docker + 挂载宿主机 `docker.sock`（支持 `docker build`）

手动重试注册：

```bash
./register-runner.sh
```

在 Admin → **CI/CD → Runners → Instance runners** 中可看到已注册的 Runner。

### CI 冒烟测试

```bash
./ci-smoke-test.sh
```

测试项目：`root/cicd-smoke-test`，会触发一条 alpine 流水线验证 Runner。

> Runner 作业容器在 `gitlab_net` 内克隆代码，使用 `clone_url=http://gitlab`（勿用 `localhost`）。

## 生产注意事项

1. **版本锁定**：在 `.env` 中固定 `GITLAB_CE_VERSION`，升级前阅读 [GitLab Release Notes](https://about.gitlab.com/releases/)。
2. **HTTPS**：生产环境将 `GITLAB_URL` 改为 `https://...`，建议前置 Caddy/Nginx/Traefik 做 TLS 终结。
3. **密码**：由 bootstrap 自动生成（纯 hex，兼容 Redis URL）。查看：`cat data/.credentials`
4. **备份**：数据目录在 `./data/`；可用 `docker exec gitlab gitlab-backup create` 创建备份。
5. **调优**：按主机规格调整 `.env` 中 `GITLAB_PUMA_WORKERS`、`GITLAB_SIDEKIQ_CONCURRENCY` 及 PostgreSQL `command` 中的内存参数。

## 端口

| 服务 | 默认端口 |
|------|----------|
| HTTP | 8000 |
| HTTPS | 8443 |
| Git SSH | 2222 |

## 目录结构

```
gitlab/
├── compose.yml
├── .env.example
├── bootstrap.sh
└── data/
    ├── postgresql/
    ├── redis-cache/
    ├── redis-persistent/
    ├── redis-sessions/
    ├── gitlab/{config,log,data,backups}/
    └── gitlab-runner/config/
```
