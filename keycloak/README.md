# Keycloak Docker Compose

这是一个使用 Docker Compose 部署 Keycloak 的配置。Keycloak 是一个开源的身份和访问管理解决方案。

## 功能特性

- 基于 Keycloak 22.0 版本
- 使用 PostgreSQL 15 作为后端数据库
- 支持环境变量配置
- 包含健康检查
- 自动初始化配置

## 快速开始

1. 初始化环境：

```bash
./bootstrap.sh
```

2. 启动服务：

```bash
docker compose up -d
```

3. 访问服务：

打开浏览器访问 http://localhost:8080 即可进入 Keycloak 管理控制台。

默认管理员账号：
- 用户名：admin
- 密码：admin123

## 环境变量

主要的环境变量配置：

### Keycloak 配置
- `KEYCLOAK_ADMIN`: 管理员用户名
- `KEYCLOAK_ADMIN_PASSWORD`: 管理员密码
- `KC_DB`: 数据库类型
- `KC_DB_URL`: 数据库连接URL
- `KC_DB_USERNAME`: 数据库用户名
- `KC_DB_PASSWORD`: 数据库密码
- `KC_HOSTNAME`: 主机名
- `KC_PROXY`: 代理模式

### PostgreSQL 配置
- `POSTGRES_DB`: 数据库名
- `POSTGRES_USER`: 数据库用户
- `POSTGRES_PASSWORD`: 数据库密码

## 数据持久化

数据存储在以下目录：
- PostgreSQL 数据: `./data/postgres`

## 健康检查

配置包含了对 PostgreSQL 和 Keycloak 服务的健康检查：
- PostgreSQL: 每10秒检查一次数据库连接
- Keycloak: 每30秒检查一次服务健康状态

## 注意事项

1. 首次部署时请修改默认的管理员密码
2. 生产环境部署时建议：
   - 使用更强的密码
   - 配置 HTTPS
   - 根据实际需求调整内存限制
   - 配置适当的备份策略

## 故障排除

如果遇到问题，可以通过以下命令查看日志：

```bash
# 查看所有容器日志
docker compose logs

# 查看特定服务日志
docker compose logs keycloak
docker compose logs postgres
```