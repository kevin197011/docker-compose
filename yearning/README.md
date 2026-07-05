# Yearning

Yearning SQL 审计。

## 部署

```bash
cd yearning
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 8000 | Web |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
