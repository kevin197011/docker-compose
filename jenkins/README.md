# Jenkins

Jenkins LTS。

## 部署

```bash
cd jenkins
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 8080 | HTTP |
| 50000 |  |

http://localhost:8080
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
