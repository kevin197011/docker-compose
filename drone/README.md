# Drone CI

Drone Server + Docker Runner。

## 部署

```bash
cd drone
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 80 | HTTP |
| 443 | HTTPS |
| 9000 | HTTP |

端口见 compose.yml，部署前改 GitLab OAuth 等环境变量。
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
