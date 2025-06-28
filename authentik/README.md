# Authentik Docker Compose

这是一个使用 Docker Compose 部署 Authentik 的配置。Authentik 是一个现代化的身份认证和授权管理平台，提供单点登录(SSO)、多因素认证(MFA)等功能。

## 功能特性

- 基于 Authentik 2024.2.1 版本
- 使用 PostgreSQL 15 作为数据库
- 使用 Redis 7 作为缓存和会话存储
- 支持邮件通知配置
- 包含健康检查
- 数据持久化
- 支持自定义模板
- 支持 SSL/TLS 证书

## 快速开始

1. 初始化环境：

```bash
./bootstrap.sh
```

2. 修改 `.env` 文件中的配置（特别是邮件配置和密码）

3. 启动服务：

```bash
docker compose up -d
```

4. 访问服务：

打开浏览器访问 http://localhost:9000 即可进入 Authentik 管理界面。

API 接口地址：https://localhost:9443

## 环境变量

### PostgreSQL 配置
- `POSTGRES_USER`: 数据库用户名
- `POSTGRES_PASSWORD`: 数据库密码
- `POSTGRES_DB`: 数据库名称

### Redis 配置
- `REDIS_PASSWORD`: Redis 密码

### Authentik 配置
- `AUTHENTIK_SECRET_KEY`: 加密密钥（自动生成）
- `AUTHENTIK_ERROR_REPORTING__ENABLED`: 错误报告开关
- `AUTHENTIK_PORT`: Web 界面端口
- `AUTHENTIK_PORT_API`: API 端口

### SMTP 配置
- `AUTHENTIK_EMAIL__HOST`: SMTP 服务器地址
- `AUTHENTIK_EMAIL__PORT`: SMTP 端口
- `AUTHENTIK_EMAIL__USERNAME`: 邮箱用户名
- `AUTHENTIK_EMAIL__PASSWORD`: 邮箱密码
- `AUTHENTIK_EMAIL__USE_TLS`: 是否使用 TLS
- `AUTHENTIK_EMAIL__FROM`: 发件人地址

## 目录结构

- `data/postgresql`: PostgreSQL 数据存储
- `data/redis`: Redis 数据存储
- `media`: 媒体文件存储
- `custom-templates`: 自定义模板目录
- `certs`: SSL/TLS 证书目录

## 健康检查

配置包含了对 PostgreSQL、Redis 和 Authentik 服务的健康检查，确保服务的可靠运行。

## 备份

建议定期备份以下目录：
- `data/postgresql`
- `data/redis`
- `media`
- `custom-templates`
- `certs`

## 故障排除

1. 如果服务无法启动，检查日志：
```bash
docker compose logs -f
```

2. 如果数据库连接失败：
```bash
docker compose logs postgresql
```

3. 如果 Redis 连接失败：
```bash
docker compose logs redis
```

## 安全建议

1. 修改所有默认密码
2. 配置 HTTPS
3. 启用多因素认证
4. 定期更新版本
5. 配置数据备份

## 升级说明

1. 备份所有数据
2. 拉取新版本镜像：
```bash
docker compose pull
```
3. 重启服务：
```bash
docker compose down
docker compose up -d
```

## 相关链接

- [Authentik 官方文档](https://goauthentik.io/docs/)
- [Authentik GitHub](https://github.com/goauthentik/authentik)
- [Docker Hub](https://hub.docker.com/r/goauthentik/server)