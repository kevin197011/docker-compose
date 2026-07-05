# MariaDB

MariaDB 数据库。

## 部署

```bash
cd mariadb
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 3306 | MySQL |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
