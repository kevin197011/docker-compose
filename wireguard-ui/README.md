# WireGuard UI

WireGuard + Web 管理界面。

## 部署

```bash
cd wireguard-ui
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 5000 | Web UI |
| 51820 | WireGuard |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
