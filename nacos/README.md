# Nacos

Nacos 3.2.4 配置中心与服务发现（`nacos/nacos-server`，standalone + Derby）。

## 部署

```bash
cd nacos
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 8080 | 控制台 |
| 8848 | HTTP API |
| 9848 | gRPC |

控制台：http://localhost:8080

从 2.x 升级会不兼容旧 Derby 数据，需先停掉再清空 `./data/` 后启动。
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
