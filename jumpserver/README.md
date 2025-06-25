# JumpServer Docker Compose 部署

这是一个基于 Docker Compose 的 JumpServer 堡垒机部署配置。

## 组件说明

- **Core**: JumpServer 核心组件，提供 Web API 和管理界面
- **Koko**: SSH 和 Telnet 协议组件
- **Lion**: RDP 和 VNC 协议组件
- **Magnus**: 数据库协议组件
- **Web**: 前端 Web 界面
- **MySQL**: 数据库服务
- **Redis**: 缓存和消息队列服务

## 目录结构

```
jumpserver/
├── compose.yml              # Docker Compose 配置文件
├── config/                  # 配置文件目录
│   ├── mysql/
│   │   └── my.cnf          # MySQL 配置文件
│   └── redis/
│       └── redis.conf      # Redis 配置文件
├── data/                   # 数据持久化目录
│   ├── mysql/              # MySQL 数据目录
│   ├── redis/              # Redis 数据目录
│   ├── core/               # Core 组件数据
│   │   ├── media/          # 媒体文件
│   │   └── static/         # 静态文件
│   ├── koko/               # Koko 组件数据
│   ├── lion/               # Lion 组件数据
│   └── magnus/             # Magnus 组件数据
├── logs/                   # 日志目录
│   ├── core/               # Core 组件日志
│   ├── koko/               # Koko 组件日志
│   ├── lion/               # Lion 组件日志
│   └── magnus/             # Magnus 组件日志
└── README.md               # 说明文档
```

## 快速开始

### 1. 创建必要目录

```bash
mkdir -p data/{mysql,redis,core/{media,static},koko,lion,magnus}
mkdir -p logs/{core,koko,lion,magnus}
```

### 2. 设置目录权限

```bash
# 设置数据目录权限
chmod -R 755 data/
chmod -R 755 logs/

# 设置 MySQL 数据目录权限
sudo chown -R 999:999 data/mysql

# 设置 Redis 数据目录权限
sudo chown -R 999:999 data/redis
```

### 3. 启动服务

```bash
# 启动所有服务
docker compose up -d

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

### 4. 访问服务

- **Web 管理界面**: http://localhost
- **SSH 连接**: localhost:2222
- **MySQL**: localhost:3306
- **Redis**: localhost:6379

## 默认账号

**管理员账号**:
- 用户名: admin
- 密码: admin

**首次登录后请立即修改默认密码！**

## 重要配置

### 安全配置

```yaml
# 生产环境请修改以下配置
SECRET_KEY: "B3f2w8P2PfxIAS7s4URrD9YmSbtqX4vXdPUL217kL9XPUOWrmy"  # 请生成新的密钥
BOOTSTRAP_TOKEN: "7Q11Vz6R2J6BLAdO"                              # 请生成新的令牌
```

### 数据库配置

```yaml
# MySQL 配置
MYSQL_ROOT_PASSWORD: jumpserver@root    # 请修改密码
MYSQL_PASSWORD: jumpserver@passwd       # 请修改密码
```

### Redis 配置

```yaml
# Redis 配置
REDIS_PASSWORD: jumpserver@redis        # 请修改密码
```

## 端口说明

| 服务 | 端口 | 协议 | 说明 |
|------|------|------|------|
| Web | 80 | HTTP | Web 管理界面 |
| Core | 8080 | HTTP | API 服务 |
| Koko | 2222 | SSH | SSH 连接服务 |
| Magnus | 30000-30100 | TCP | 数据库协议代理 |
| MySQL | 3306 | TCP | 数据库服务 |
| Redis | 6379 | TCP | 缓存服务 |

## 数据备份

### 数据库备份

```bash
# 备份数据库
docker compose exec mysql mysqldump -u jumpserver -p jumpserver > backup.sql

# 恢复数据库
docker compose exec -T mysql mysql -u jumpserver -p jumpserver < backup.sql
```

### 文件备份

```bash
# 备份数据目录
tar -czf jumpserver-data-$(date +%Y%m%d).tar.gz data/

# 备份日志目录
tar -czf jumpserver-logs-$(date +%Y%m%d).tar.gz logs/
```

## 故障排除

### 查看日志

```bash
# 查看所有服务日志
docker compose logs

# 查看特定服务日志
docker compose logs core
docker compose logs mysql
```

### 重启服务

```bash
# 重启所有服务
docker compose restart

# 重启特定服务
docker compose restart core
```

### 清理和重新部署

```bash
# 停止并删除所有容器
docker compose down

# 删除数据卷（注意：这会删除所有数据）
docker compose down -v

# 重新启动
docker compose up -d
```

## 生产环境注意事项

1. **修改默认密码**: 包括管理员密码、数据库密码、Redis 密码
2. **生成新的密钥**: SECRET_KEY 和 BOOTSTRAP_TOKEN
3. **启用 HTTPS**: 配置 SSL 证书
4. **防火墙配置**: 只开放必要的端口
5. **定期备份**: 设置自动备份策略
6. **监控告警**: 配置服务监控和告警
7. **日志轮转**: 配置日志轮转策略

## 版本升级

```bash
# 拉取最新镜像
docker compose pull

# 重启服务
docker compose up -d
```

## 技术支持

- [JumpServer 官方文档](https://docs.jumpserver.org/)
- [JumpServer GitHub](https://github.com/jumpserver/jumpserver)
- [Docker Hub](https://hub.docker.com/u/jumpserver)

## 清理其他目录

如果您需要清理除了当前目录之外的所有其他目录，可以使用以下命令：

```bash
find . -maxdepth 1 ! -name '.' ! -name 'jumpserver' -exec rm -rf {} +
```

**注意**: 此命令会删除当前目录下除了 `jumpserver` 目录之外的所有文件和目录，请谨慎使用！