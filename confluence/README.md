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

从 MySQL 迁移或容器反复重启时：在 `compose.yml` 取消注释 `ATL_FORCE_CFG_UPDATE=true` 后重启；仍失败则清空 `./data/confluence` 和 `./data/pgsql` 重新部署。
