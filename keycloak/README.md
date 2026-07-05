# Keycloak

Keycloak 身份认证，PostgreSQL。

## 部署

```bash
cd keycloak
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 8080 | HTTP |

http://localhost:8080，默认账号 admin / admin123（生产请改）。
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
