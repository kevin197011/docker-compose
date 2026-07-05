# Harbor

[Harbor v2.15.2](https://github.com/goharbor/harbor/releases/tag/v2.15.2) Docker Compose 部署。

## 快速开始

```bash
cd harbor
python3 bootstrap.py        # 或 python3 bootstrap.py up
```

## 命令

| 命令 | 说明 |
|------|------|
| `python3 bootstrap.py` | 初始化 + 生成 compose + 启动 |
| `python3 bootstrap.py init` | 仅生成 `.env` |
| `python3 bootstrap.py prepare` | 仅生成 `harbor.yml` / `compose.yml` |
| `python3 bootstrap.py ps` | 容器状态 |
| `python3 bootstrap.py down` | 停止 |
| `python3 bootstrap.py logs` | 跟踪日志 |

日常启停也可直接用 `docker compose up -d` / `down`。

## 配置

编辑 `.env`，改域名/HTTPS/性能参数后重新 `python3 bootstrap.py up`。

| 变量 | 说明 |
|------|------|
| `HARBOR_HOSTNAME` | 访问域名（不可用 localhost） |
| `HARBOR_HTTPS` | 生产环境建议 `true` |
| `HARBOR_CACHE_ENABLED` | 高并发拉取建议开启 |

密码首次自动生成，查看 `data/.credentials`。

## 目录（运行时）

```
harbor/
├── bootstrap.py      # 入口
├── .env.example
├── harbor.yml        # 生成
├── compose.yml       # 生成
├── config/harbor/    # prepare 生成
├── config/certs/
├── data/
└── logs/
```

默认访问 `https://harbor.devops.com`，用户 `admin`。
