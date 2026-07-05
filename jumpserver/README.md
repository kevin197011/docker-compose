# JumpServer

JumpServer 堡垒机（jms_all）。

## 部署

```bash
cd jumpserver
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 80 | HTTP |
| 2222 | SSH |
| 3306 | MySQL |
| 6379 | Redis |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
