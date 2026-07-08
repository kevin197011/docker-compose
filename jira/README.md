# Jira

官方 `atlassian/jira-software:11.3.7`（Java 21）+ PostgreSQL 17。默认仅 HTTP `:8080`；HTTPS 由外部 Nginx 反代。`compose.yml` 内嵌 nginx 可选启用（仅 HTTP）。

## 部署

```bash
cd jira
python3 bootstrap.py
```

`atlassian-agent.jar` 优先从 `../confluence/atlassian-agent.jar` 复制，否则从 `../../atlassian-agent/target/` 复制。

## 端口

| 端口 | 说明 |
|------|-----|
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

生成 license（自动从 `dbconfig.xml` 读取 Server ID，Jira 11 已含 `-d`）：

```bash
./hack.sh
```

**Server ID 与重启：** `ATL_FORCE_CFG_UPDATE=true` 时每次启动都会重写 `dbconfig.xml` 并生成新 Server ID，之前生成的 license 会失效。`compose.yml` 已设为 `false`。

## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/jira`、`./data/pgsql`。

从 `haxqer/jira` 迁移到官方镜像需清空数据重来：

```bash
docker compose down
rm -rf data/jira/* data/pgsql/*
python3 bootstrap.py
```

本地直连访问用 `http://localhost:8080`。

`upm-init` 将 `config/upmconfig/` 以 `root:root` 写入 Docker volume 并只读挂载到 `/opt/upmconfig`。
