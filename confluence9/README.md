# Confluence 9.0.2 (haxqer) + PostgreSQL 13

基于 [掘金：Docker 部署 Confluence 9.0.2](https://juejin.cn/post/7409882784058605579) 与官方推荐的 PostgreSQL，落到本仓库 `data/` / `config/` 约定。

| 项 | 值 |
|---|---|
| 镜像 | `haxqer/confluence:9.0.2` |
| Home | `/var/confluence` → `./data/confluence` |
| Agent | 镜像内 `/var/agent/atlassian-agent.jar` |
| 数据库 | `postgres:13`（文章同款；容器内主机名 `pgsql`） |
| HTTP | `8090`（可用 `.env` 改 `CONFLUENCE_HTTP_PORT`） |
| 容器名 | `confluence9` / `confluence9-pgsql` |

与根目录 `./confluence`（官方 10.x）互不冲突；**不要同时占用同一宿主机 8090**。

**Server ID / 授权：** `ATL_FORCE_CFG_UPDATE` 默认 `false`，重启不重写 `confluence.cfg.xml`，避免每次换 Server ID 导致 license 失效。仅改 JDBC 等环境变量时临时改 `true`，改完再改回 `false`。

**反代（可选）：** 默认 `config/server.xml` = 直连 `http://宿主机:8090`，换机器可直接用。若走 HTTPS 反代（Orb / nginx）：拷 `config/server.xml.proxy.example` → `config/server.xml.local`，改 `proxyName`，`.env` 设 `CONFLUENCE_SERVER_XML=config/server.xml.local`（该文件 gitignore）。安装只走公网 URL，勿混用 `:8090`。

安装向导用户目录一步选 **在 Confluence 内管理用户**，不要选连 Jira（除非真有 Jira）。

**换机全新部署：** 只带配置目录（不要拷本机 `data/` / `.env`）。`python3 bootstrap.py` → 向导填 `pgsql:5432` → `./hack.sh` 出新 license（新 Server ID）。需能拉 `haxqer/confluence:9.0.2` 与 `postgres:13`，建议 ≥4GB 内存给 Confluence，8090/8091 空闲。

## 快速开始

```bash
cd confluence9
python3 bootstrap.py          # 建目录、写 .env、拉镜像、起栈
# 或
cp .env.example .env          # 改 POSTGRES_PASSWORD
docker compose up -d
```

浏览器：`http://localhost:8090`

### 安装向导（数据库）

| 字段 | 值 |
|---|---|
| Database type | PostgreSQL |
| Hostname | `pgsql`（Compose 服务名，**不是** `localhost`） |
| Port | `5432` |
| Database | `.env` 里 `POSTGRES_DB`（默认 `confluence`） |
| Username / Password | `.env` 里对应项 |

文章强调：尽量用 PostgreSQL，避免 MySQL 兼容坑。

### 许可证

打开安装页拿到 **Server ID** 后：

```bash
./hack.sh                 # product=conf，自动读 Server ID
./hack.sh <plugin-key>    # 插件 license
```

把输出的 `AAA…` 贴进 Confluence 许可框。

## 常用命令

```bash
docker compose logs -f confluence
docker compose down           # 不停数据卷（本机 bind mount）
# 重置安装（清数据）
docker compose down
rm -rf data/confluence data/pgsql
python3 bootstrap.py
```

## 现网部署（devops-wiki-01）

| 项 | 值 |
|---|---|
| 主机 | `10.173.32.9`（`devops-wiki-01` / `asia-east2-c`） |
| 目录 | `/opt/wiki`（对齐 `.7` 的 `/opt/confluence`） |
| 容器 | `wiki` + `wiki-pgsql` |
| 端口 | `8090` / `8091` |
| 反代域名 | `https://confluence.qj-devops.com` → `.9`（nginx `@ devops-nginx-01`；旧站 `wiki.qj-devops.com` 仍指 `.7`） |

```bash
# 主机上
cd /opt/wiki
sudo docker compose ps
sudo docker compose logs -f confluence
./hack.sh
```

切到公网域名时：

1. `cp config/server.xml.wiki.qj-devops.com config/server.xml.local`
2. `.env` 设 `CONFLUENCE_SERVER_XML=config/server.xml.local`
3. nginx `wiki.qj-devops.com` upstream 改为 `10.173.32.9:8090` / `:8091`
4. `sudo docker compose up -d confluence`

## 参考

- 文章：https://juejin.cn/post/7409882784058605579
- 等价单容器：`docker run -p 8090:8090 -v …:/var/confluence --network … -e TZ=Asia/Shanghai haxqer/confluence:9.0.2`
