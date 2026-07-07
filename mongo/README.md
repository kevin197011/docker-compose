# MongoDB

MongoDB 4.4.4，无认证（仅内网/开发环境使用）。

## 部署

```bash
cd mongo
python3 bootstrap.py
```

## 端口

| 端口 | 说明 |
|------|------|
| 27017 | MongoDB |

连接示例：

```bash
mongosh mongodb://localhost:27017
```

## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/mongo`。
