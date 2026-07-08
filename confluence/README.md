# Confluence

Confluence 9.5.3（`haxqer/confluence`）+ PostgreSQL 15，可选 Nginx SSL。

> `haxqer/confluence:10.0.2` 内置 Java 17，Confluence 10 需 Java 21，会触发 `UnsupportedClassVersionError` 并反复重启。

## 部署

```bash
cd confluence
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 8090 | Web |

编辑 `.env.example` 后 bootstrap 会渲染 nginx/server 配置。

数据库连接（安装向导手动填写时）：

| 字段 | 值 |
|------|-----|
| Host | `pgsql`（不要用 `localhost`） |
| Port | `5432` |
| Database | `confluence`（见 `.env` 的 `POSTGRES_DB`） |
| Username | `confluence` |
| Password | 见 `.env` 的 `POSTGRES_PASSWORD` |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。

本地直连访问用 `http://localhost:8090`（默认 `server.xml` 不走 HTTPS 反代）。启用 Nginx 后需在 `templates/server.xml.tmpl` 切换为带 `proxyName` 的 Connector 并重新 `bootstrap.py`。

安装向导中途报错（`Spring Application context has not been set`）说明 setup 状态损坏，需重置：

```bash
docker compose down
rm -rf data/confluence/* data/pgsql/*
python3 bootstrap.py
```

然后重新走完整安装流程，数据库 Host 填 `pgsql`，不要跳过管理员创建步骤。
