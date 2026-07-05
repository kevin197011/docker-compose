# WireGuard

WireGuard VPN（wg-easy）。

## 部署

```bash
cd wireguard
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 51820 | WireGuard |
| 51821 | Web UI |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
