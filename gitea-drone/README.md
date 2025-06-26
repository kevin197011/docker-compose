# Gitea + Drone CI/CD with Nginx

基于 Docker Compose 的现代化 Gitea + Drone CI/CD 环境，配置 Nginx 反向代理和 SSL 支持。

## 特性

- **Nginx 反向代理**: 支持 SSL 终端和安全头设置
- **SSL/HTTPS 支持**: 自动生成自签名证书，支持 Let's Encrypt
- **自动IP获取**: 智能检测并使用本机IP地址，无需手动配置
- **最新版本**: 使用最新稳定版本的 Gitea、Drone 和 Nginx
- **健康检查**: 内置服务健康检查，确保服务正常启动
- **一键部署**: 简化的部署流程，几分钟内完成CI/CD环境搭建
- **完整集成**: Nginx + Gitea + Drone + Runner 完整CI/CD解决方案
- **安全加固**: 包含速率限制、安全头和防护配置

## 版本信息

| 服务 | 版本 | 说明 |
|------|------|------|
| Nginx | 1.25-alpine | 反向代理和SSL终端 |
| Gitea | 1.21.5 | Git 仓库管理平台 |
| Drone | 2.23.0 | CI/CD 服务器 |
| Drone Runner | 1.8.3 | CI/CD 任务执行器 |

## 快速开始

### 环境变量配置

推荐使用 .env 文件进行配置：

```bash
# 创建配置文件
cp .env.example .env

# 编辑配置文件
vim .env
```

或者使用环境变量：

```bash
# 必需配置
export IP_ADDRESS="your-server-ip"
export DOMAIN="your-domain.com"  # 可选，默认使用 IP_ADDRESS

# 可选配置
export NGINX_VERSION="1.25-alpine"
export GITEA_VERSION="1.21.5"
export DRONE_VERSION="2.23.0"
export DRONE_RUNNER_VERSION="1.8.3"
```

### 一键部署

```bash
# 创建配置文件（首次运行）
./bootstrap.sh --create-env

# 编辑配置文件
vim .env

# 启动所有服务
./bootstrap.sh
```

### 命令行选项

```bash
# 显示帮助信息
./bootstrap.sh --help

# 创建 .env 配置模板
./bootstrap.sh --create-env
```

### 手动部署（可选）

```bash
# 手动启动服务
docker compose up -d

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

## 服务访问

部署完成后，可通过以下地址访问：

### 主要访问地址（通过域名和 HTTPS）
- **Gitea**: https://git.example.com (Git 仓库管理)
- **Drone**: https://drone.example.com (CI/CD 控制台)

### 直接访问地址（通过 IP 和端口）
- **Gitea**: http://your-ip:3000 (直接访问)
- **Drone**: http://your-ip:3001 (直接访问)
- **Drone Runner**: http://your-ip:3002 (任务执行器状态)

### 其他服务
- **Gitea SSH**: git.example.com:2222 (Git SSH 访问)
- **Nginx**: http://your-ip:80, https://your-ip:443 (反向代理)
- **Nginx 健康检查**: http://your-ip/health

### 内部端口
- **Drone RPC**: 9000 (内部 RPC 通信)

> 所有端口都已暴露，支持直接访问和代理访问

## SSL 证书配置

### 自签名证书（开发环境）

部署脚本会自动生成自签名证书，适用于开发和测试：

```bash
# 证书文件位置
data/ssl/your-domain.com.crt  # 证书文件
data/ssl/your-domain.com.key  # 私钥文件
```

### Let's Encrypt 证书（生产环境）

1. 安装 certbot：
   ```bash
   # Ubuntu/Debian
   sudo apt install certbot

   # CentOS/RHEL
   sudo yum install certbot
   ```

2. 获取证书：
   ```bash
   sudo certbot certonly --standalone -d your-domain.com
   ```

3. 复制证书到数据目录：
   ```bash
   sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem data/ssl/your-domain.com.crt
   sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem data/ssl/your-domain.com.key
   sudo chown $USER:$USER data/ssl/your-domain.com.*
   ```

4. 重启 nginx：
   ```bash
   docker compose restart nginx
   ```

### 自定义证书

将您的证书文件放置在 `data/ssl/` 目录：
- `data/ssl/your-domain.com.crt` - 证书文件
- `data/ssl/your-domain.com.key` - 私钥文件

注意：这些文件会被挂载到 nginx 容器的 `/etc/nginx/ssl/` 目录

## 配置流程

### 1. Gitea 初始化

1. 访问 Gitea Web 界面 (https://your-domain.com)
2. 完成初始化设置（数据库、管理员账户等）
3. 创建第一个仓库

### 2. 配置 OAuth2 应用

1. 在 Gitea 中进入 **设置** → **应用** → **管理 OAuth2 应用程序**
2. 创建新的 OAuth2 应用：
   - **应用名称**: Drone
   - **重定向 URI**: `http://your-ip:3001/login`
3. 记录生成的 **Client ID** 和 **Client Secret**

### 3. 配置 Drone

1. 更新 .env 文件中的 OAuth2 配置：
   ```bash
   # 编辑 .env 文件
   vim .env

   # 添加或更新以下配置
   DRONE_GITEA_CLIENT_ID=your-client-id
   DRONE_GITEA_CLIENT_SECRET=your-client-secret
   DRONE_USER_CREATE=username:your-gitea-admin-user,admin:true
   ```

2. 重新启动 Drone 服务：
   ```bash
   docker compose restart drone drone-runner
   ```

### 4. 验证集成

1. 访问 Drone Web 界面
2. 使用 Gitea 账户登录
3. 同步仓库并启用 CI/CD

## 目录结构

```
gitea-drone/
├── compose.yml                    # Docker Compose 配置
├── bootstrap.sh                   # 一体化部署脚本
├── .env.example                   # 环境配置示例文件
├── .env                          # 环境配置文件（需要创建）
├── README.md                     # 说明文档
├── config/                       # 配置文件目录
│   └── nginx/                    # Nginx 配置
│       ├── nginx.conf            # 主配置文件
│       └── conf.d/               # 虚拟主机配置
│           └── gitea.conf        # Gitea 代理配置
└── data/                         # 数据持久化目录
    ├── gitea/                    # Gitea 数据
    ├── drone/                    # Drone 数据
    ├── nginx/                    # Nginx 运行时数据
    │   ├── logs/                 # 访问日志
    │   └── cache/                # 缓存目录
    └── ssl/                      # SSL 证书目录
        ├── your-domain.com.crt   # SSL 证书
        └── your-domain.com.key   # SSL 私钥
```

## Nginx 配置特性

### 安全特性
- HTTP 到 HTTPS 自动重定向
- 安全头设置 (HSTS, XSS 保护等)
- 速率限制 (登录和 API 端点)
- 隐藏敏感文件访问

### 性能优化
- Gzip 压缩
- 静态资源缓存
- 连接保持
- 缓冲优化

### Git 支持
- Git HTTP(S) 传输优化
- 大文件上传支持
- WebSocket 支持 (实时功能)
- 长时间操作超时配置

## 常用命令

```bash
# 查看脚本帮助
./bootstrap.sh --help

# 创建配置文件
./bootstrap.sh --create-env

# 启动所有服务
./bootstrap.sh

# 健康检查
./health-check.sh

# 查看服务状态
docker compose ps

# 查看实时日志
docker compose logs -f

# 查看特定服务日志
docker compose logs nginx
docker compose logs gitea
docker compose logs drone

# 重启特定服务
docker compose restart nginx
docker compose restart gitea
docker compose restart drone

# 停止所有服务
docker compose down

# 完全清理（包括数据）
docker compose down -v
rm -rf data/
```

## 故障排除

### 1. SSL 证书问题

```bash
# 检查证书文件
ls -la data/ssl/

# 验证证书有效性
openssl x509 -in data/ssl/your-domain.com.crt -text -noout

# 检查 nginx 配置
docker compose exec nginx nginx -t
```

### 2. 服务无法启动

```bash
# 检查端口占用
netstat -tuln | grep -E ":(80|443|3001|3002|2222)"

# 查看详细日志
docker compose logs nginx
docker compose logs gitea
docker compose logs drone
```

### 3. IP地址获取失败

```bash
# 手动设置IP地址
export IP_ADDRESS="your-manual-ip"
export DOMAIN="your-domain.com"
./bootstrap.sh
```

### 4. Nginx 配置问题

```bash
# 测试 nginx 配置
docker compose exec nginx nginx -t

# 重新加载配置
docker compose exec nginx nginx -s reload

# 查看 nginx 错误日志
docker compose logs nginx
tail -f data/nginx/logs/error.log
```

### 5. OAuth2 配置问题

- 确保重定向URI正确设置
- 检查Client ID和Secret是否正确
- 验证Drone服务是否可以访问Gitea

### 6. 权限问题

```bash
# 修复数据目录权限
sudo chown -R 1000:1000 data/
chmod -R 755 data/
chmod 600 data/ssl/*.key
chmod 644 data/ssl/*.crt
```

## 高级配置

### 自定义 Nginx 配置

编辑 `config/nginx/conf.d/gitea.conf` 文件来自定义代理设置：

```bash
# 编辑配置后重启
vim config/nginx/conf.d/gitea.conf
docker compose restart nginx
```

### 自定义版本

```bash
# 设置自定义版本
export NGINX_VERSION="1.25-alpine"
export GITEA_VERSION="1.21.5"
export DRONE_VERSION="2.23.0"
export DRONE_RUNNER_VERSION="1.8.3"
./bootstrap.sh
```

### 外部数据库

默认使用SQLite，如需使用MySQL/PostgreSQL，请修改相应的环境变量。

### CDN 和缓存

可以配置 CDN 来加速静态资源访问：

```nginx
# 在 gitea.conf 中添加
location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    # 可以添加 CDN 域名
}
```

## 监控和维护

### 日志轮转

```bash
# 配置 logrotate
sudo vim /etc/logrotate.d/gitea-nginx
```

### 健康检查

```bash
# 检查服务健康状态
curl -f http://localhost/health
curl -f http://localhost:3001/healthz
```

### 备份

```bash
# 备份重要数据
tar -czf gitea-drone-backup-$(date +%Y%m%d).tar.gz data/
```

## 清理命令

```bash
# 停止并删除所有服务和数据
find . -maxdepth 1 ! -name '.' ! -name 'gitea-drone' -exec rm -rf {} +
```