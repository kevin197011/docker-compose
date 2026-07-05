# Graylog

Graylog 日志平台（含 Elasticsearch、MongoDB）。

## 部署

```bash
cd graylog
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 1514 |  |
| 9000 | HTTP |
| 12201 |  |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
