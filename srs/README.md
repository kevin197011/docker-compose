# SRS

SRS 流媒体（RTMP / HLS / WebRTC）。

## 部署

```bash
cd srs
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 1935 | RTMP |
| 1985 | HTTP API |
| 8080 | HTTP |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
