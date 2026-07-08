# Confluence

官方 `atlassian/confluence:10.2.13`（Java 21）+ PostgreSQL 17。默认仅 HTTP `:8090`；HTTPS 由外部 Nginx 反代。`compose.yml` 内嵌 nginx 可选启用（仅 HTTP）。

## 部署

```bash
cd confluence
python3 bootstrap.py
```

首次运行若缺少 `atlassian-agent.jar`，会从 `haxqer/confluence:9.5.3` 提取到当前目录。

## 端口

| 端口 | 说明 |
|------|-----|
| 8090 | Web |
| 8091 | Synchrony |

数据库连接（安装向导手动填写时）：

| 字段 | 值 |
|------|-----|
| Host | `pgsql`（不要用 `localhost`） |
| Port | `5432` |
| Database | `confluence`（见 `.env` 的 `POSTGRES_DB`） |
| Username | `confluence` |
| Password | 见 `.env` 的 `POSTGRES_PASSWORD` |

## 激活

`compose.yml` 已通过 `JVM_SUPPORT_RECOMMENDED_ARGS` 注入 `-javaagent`；仅挂载 jar 不会生效。

启动后在 `docker compose logs confluence` 中应看到：

```
============================== agent working ==============================
atlassian-agent: Version2LicenseDecoder patched
```

生成 license（自动从容器日志读取 Server ID，Confluence 10 已含 `-d`）：

```bash
./hack.sh
```

`atlassian-agent.jar` 优先从 `../../atlassian-agent/target/atlassian-agent-jar-with-dependencies.jar` 复制，否则从 `haxqer/confluence:9.5.3` 提取。

**Server ID 与重启：** `ATL_FORCE_CFG_UPDATE=true` 时每次启动都会重写 `confluence.cfg.xml` 并生成新 Server ID，之前生成的 license 会失效。`compose.yml` 已设为 `false`；仅首次装库或改 JDBC 等环境变量时临时改回 `true`，改完再改回 `false` 并 `docker compose up -d --force-recreate confluence`。

## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/confluence`、`./data/pgsql`。

从 `haxqer/confluence` 迁移到官方镜像需清空数据重来：

```bash
docker compose down
rm -rf data/confluence/* data/pgsql/*
python3 bootstrap.py
```

本地直连访问用 `http://localhost:8090`。

`bootstrap.py` 会在 `config/upmconfig/` 维护 UPM 配置；`upm-init` 服务将其以 `root:root` 写入 Docker volume 并只读挂载到 `/opt/upmconfig`，满足 UPM 安全检查（属主不能是 `confluence`）。

安装向导中途报错（`Spring Application context has not been set`）说明 setup 状态损坏，执行上面的重置命令后重新安装。
