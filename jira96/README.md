# Jira 9.6

官方 `atlassian/jira-software:9.6.0` + PostgreSQL 14（[Jira 9.6 支持平台](https://confluence.atlassian.com/adminjiraserver0906/supported-platforms-1217304507.html)：PG 10–14）。默认仅 HTTP `:8080`。

## 部署

```bash
cd jira96
python3 bootstrap.py
```

`atlassian-agent.jar` 优先从 `../confluence/atlassian-agent.jar` 复制，否则从 `../../atlassian-agent/target/` 复制。

## 端口

| 端口 | 说明 |
|------|------|
| 8080 | Web |

数据库连接（安装向导手动填写时）：

| 字段 | 值 |
|------|-----|
| Host | `pgsql`（不要用 `localhost`） |
| Port | `5432` |
| Database | `jira`（见 `.env` 的 `POSTGRES_DB`） |
| Username | `jira` |
| Password | 见 `.env` 的 `POSTGRES_PASSWORD` |

## 激活

`compose.yml` 已通过 `JVM_SUPPORT_RECOMMENDED_ARGS` 注入 `-javaagent`；仅挂载 jar 不会生效。

```bash
./hack.sh
```

**Server ID 与重启：** `ATL_FORCE_CFG_UPDATE=true` 时每次启动都会重写 `dbconfig.xml` 并生成新 Server ID。`compose.yml` 已设为 `false`。

## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/jira`、`./data/pgsql`。

从其他版本迁移需清空数据重来：

```bash
docker compose down
rm -rf data/jira/* data/pgsql/*
python3 bootstrap.py
```

本地直连：`http://localhost:8080`。容器名：`jira96` / `jira96-pgsql`（与 `jira/` 目录隔离）。
