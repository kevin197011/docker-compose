# Nacos

Nacos 配置中心与服务发现。

## 部署

```bash
cd nacos
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 8848 | HTTP |
| 9848 | gRPC |
| 9849 | gRPC |

控制台：http://localhost:8848/nacos
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
