# Atlassian Confluence Docker Compose 部署

## 📖 项目简介

基于 Docker Compose 的 Atlassian Confluence 企业级知识管理平台部署方案，支持 Nginx 反向代理和 SSL 证书配置。

## ✨ 功能特性

- 🚀 一键部署，开箱即用
- 🔧 自动环境检查和初始化
- 🔐 支持 SSL 证书配置
- 🌐 Nginx 反向代理
- 🛠️ 完整的数据持久化
- 🔄 支持服务重启和升级
- 📋 详细的日志记录
- ⚙️ 基于模板的配置文件生成

## 🚀 快速开始

### 方式一：一键部署（推荐）

```bash
# 克隆项目
git clone <repository-url>
cd confluence

# 一键部署
./bootstrap.sh
```

### 方式二：分步部署

```bash
# 1. 初始化环境
./bootstrap.sh --init

# 2. 配置 SSL 证书
# 将证书文件放入 ssl 目录，文件名应与域名匹配
# 例如：域名为 wiki.example.com，则证书文件应为：
# - ssl/example.com.crt
# - ssl/example.com.key

# 3. 启动服务
docker compose up -d

# 4. 查看状态
docker compose ps
```

## 📋 系统要求

- Docker Engine 20.10+
- Docker Compose 2.0+
- 系统内存: 建议 4GB+
- 磁盘空间: 建议 20GB+

## 🌐 服务端口

- **80**: HTTP 端口
- **443**: HTTPS 端口（SSL）
- **8090**: Confluence 内部服务端口（不对外暴露）

## 🔧 配置说明

### 目录结构

```
confluence/
├── bootstrap.sh          # 一体化部署脚本
├── compose.yml          # Docker Compose 配置
├── .env                # 环境变量配置
├── nginx.conf          # Nginx 配置（自动生成）
├── server.xml          # Confluence 服务器配置（自动生成）
├── README.md           # 项目文档
├── templates/          # 配置文件模板
│   ├── nginx.conf.tmpl
│   └── server.xml.tmpl
├── ssl/               # SSL 证书目录
├── data/              # 数据目录
│   ├── confluence/    # Confluence 数据
│   └── mysql/        # MySQL 数据
└── logs/              # 日志目录
```

### 环境变量

配置文件 `.env` 中包含以下主要变量：

```bash
# Confluence 配置
CONFLUENCE_DOMAIN=wiki.example.com    # 访问域名

# 数据库配置
MYSQL_DATABASE=confluence
MYSQL_ROOT_PASSWORD=123456
MYSQL_USER=confluence
MYSQL_PASSWORD=123456

# 时区设置
TZ=Asia/Shanghai

# SSL 证书配置
SSL_CERTIFICATE=example.com.crt      # 证书文件名
SSL_CERTIFICATE_KEY=example.com.key  # 私钥文件名
```

## 📊 使用指南

### 初始化配置

```bash
# 初始化环境和配置
./bootstrap.sh --init

# 根据提示输入域名
# 系统会自动生成：
# 1. .env 配置文件
# 2. nginx.conf 配置
# 3. server.xml 配置
```

### 证书配置

1. 准备 SSL 证书文件
2. 将证书文件重命名为与域名匹配的格式
   - 示例：域名为 wiki.example.com
   - 证书文件：example.com.crt
   - 私钥文件：example.com.key
3. 将证书文件放入 `ssl` 目录

### 启动服务

```bash
# 后台启动
docker compose up -d

# 前台启动（查看日志）
docker compose up
```

### 查看状态

```bash
# 查看服务状态
docker compose ps

# 查看服务日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f confluence
docker compose logs -f nginx
docker compose logs -f mysql
```

### 停止服务

```bash
# 停止服务
docker compose down

# 停止服务并删除数据卷（谨慎使用）
docker compose down -v
```

## 🔗 访问地址

服务启动后，可以通过以下地址访问：

- HTTP: http://<your-domain>
- HTTPS: https://<your-domain>

## 🛠️ 故障排除

### 常见问题

1. **证书配置问题**
   - 检查证书文件名是否与 `.env` 中的配置匹配
   - 确保证书文件权限正确：`chmod 644 ssl/*.crt ssl/*.key`

2. **端口冲突**
   - 检查 80/443 端口是否被占用：`netstat -tulpn | grep '80\|443'`
   - 停止冲突的服务或修改端口映射

3. **数据库连接问题**
   - 检查数据库服务状态：`docker compose ps mysql`
   - 查看数据库日志：`docker compose logs mysql`

4. **Nginx 配置问题**
   - 检查生成的配置：`cat nginx.conf`
   - 验证 Nginx 配置：`docker compose exec nginx nginx -t`

### 日志查看

```bash
# 查看所有服务日志
docker compose logs

# 实时查看日志
docker compose logs -f

# 查看最近100行日志
docker compose logs --tail=100
```

## 🔄 升级指南

### 升级服务

```bash
# 1. 备份数据
tar -czf backup-$(date +%Y%m%d).tar.gz data/ ssl/ .env

# 2. 停止服务
docker compose down

# 3. 拉取最新镜像
docker compose pull

# 4. 重新启动
docker compose up -d
```

## 📚 相关资源

- [Confluence 官方文档](https://confluence.atlassian.com/doc/confluence-server-documentation-135922.html)
- [Nginx 配置指南](https://nginx.org/en/docs/)
- [Docker Compose 文档](https://docs.docker.com/compose/)

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

---

**注意**: 首次部署时，请确保已正确配置域名解析和 SSL 证书。如需帮助，请参考具体服务的官方文档。
