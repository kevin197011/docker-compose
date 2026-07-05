# Rancher

Rancher Kubernetes 管理。

## 部署

```bash
cd rancher
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 80 | HTTP |
| 443 | HTTPS |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
