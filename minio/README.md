# MinIO

MinIO 对象存储（S3 兼容）。

## 部署

```bash
cd minio
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 9000 | HTTP |
| 9001 | Console |

API :9000，Console :9001
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
