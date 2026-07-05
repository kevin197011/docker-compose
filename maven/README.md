# Maven

Sonatype Nexus 3 私有 Maven 仓库。

## 部署

```bash
cd maven
python3 bootstrap.py
```

首次启动后初始密码：

```bash
cat data/nexus-data/admin.password
```

## 端口

| 端口 | 说明 |
|------|------|
| 8081 | Nexus Web |

编辑 `.env.example` 可改版本、端口和访问 URL。Maven 客户端配置见 `config/settings.xml`。

## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/nexus-data`。
