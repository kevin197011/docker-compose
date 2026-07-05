# APISIX

APISIX API 网关，含 etcd。

## 部署

```bash
cd apisix
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 2379 |  |
| 9080 |  |
| 9180 |  |
| 9443 | HTTPS |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
