# Authentik

Authentik SSO，PostgreSQL + Redis。

## 部署

```bash
cd authentik
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 9000 | HTTP |
| 9443 | HTTPS |

Web http://localhost:9000，API https://localhost:9443。首次运行自动生成 `.env`。
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
