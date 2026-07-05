# Prometheus

Prometheus + Grafana + Alertmanager。

## 部署

```bash
cd prometheus
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 3000 | Web |
| 9090 | Prometheus |
| 9093 |  |
| 9115 |  |

Prometheus :9090，Grafana :3000
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
