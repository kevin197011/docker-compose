# GitLab

GitLab CE，外置 PostgreSQL 17 和三个 Redis 实例（cache / persistent / sessions）。内置 PG/Redis 已关闭。

## 部署

```bash
cd gitlab
python3 bootstrap.py
```

首次运行生成 `.env` 和 `data/.credentials`。重复执行会拉镜像、更新服务、注册 Runner，不会清空 `data/`。

启动大约需要 3–5 分钟：

```bash
docker compose ps
docker compose logs -f gitlab
```

访问 https://gitlab.devops.com（demo 自签证书，本机 `/etc/hosts` 加 `127.0.0.1 gitlab.devops.com`）。用户 `root`，密码见 `data/.credentials`。

## 组件

| 组件 | 镜像 |
|------|------|
| GitLab CE | `gitlab/gitlab-ce` |
| PostgreSQL | `postgres:17-alpine` |
| Redis ×3 | `redis:7-alpine` |
| Runner | `gitlab/gitlab-runner`（bootstrap 自动注册） |

## 硬件参考

| 人数 | 内存 | vCPU |
|------|------|------|
| 1–5 | 16GB | 4 |
| 5–20 | 32GB | 8 |
| 20+ | 64GB+ | 16+ |

## 运维

| 操作 | 命令 |
|------|------|
| 部署 / 升级 / 换证书 | `python3 bootstrap.py` |
| 启停 | `docker compose up -d` / `down` |

不要删除 `data/` 或在已有数据时重生成 `.env`。

Runner 重新注册：删掉 `data/gitlab-runner/config/config.toml`，再跑 `python3 bootstrap.py`。

## HTTPS

证书放 `config/certs/`，默认 `gitlab.devops.com.crt` / `.key`。`.env` 里设 `GITLAB_LISTEN_HTTPS=true`，换证书后重新 bootstrap。

## 端口

| 端口 | 用途 |
|------|------|
| 80 | HTTP |
| 443 | HTTPS |
| 2222 | Git SSH |

## 目录

```
gitlab/
├── compose.yml
├── bootstrap.py
├── .env.example
├── config/certs/
└── data/
    ├── postgresql/
    ├── redis-{cache,persistent,sessions}/
    ├── gitlab/{config,log,data,backups}/
    └── gitlab-runner/config/
```

备份：`docker exec gitlab gitlab-backup create`。
