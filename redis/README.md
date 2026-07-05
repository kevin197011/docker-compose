# Redis

Redis。

## 部署

```bash
cd redis
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 6379 | Redis |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
