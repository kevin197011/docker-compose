# Gitea

Gitea + PostgreSQL + Redis + Actions Runner（`gitea/act_runner`）。

## 部署

```bash
cd gitea
python3 bootstrap.py
```

首次运行会从 `.env.example` 生成 `.env`，按需修改后再启动。

Runner 需挂载 Docker socket，macOS 下容器以 root 运行。

## 端口

| 端口 | 说明 |
|------|------|
| 3000 | Web |
| 2222 | Git SSH |

## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/gitea`、`./data/postgres`、`./data/redis`、`./data/act-runner`。

Workflow 构建见 `docs/dev/workflow-build-push-docker.md`。
