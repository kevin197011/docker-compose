# Rancher - Kubernetes Management Platform

[Rancher](https://rancher.com/) 是一个开源的企业级 Kubernetes 管理平台，提供了在任何地方运行 Kubernetes 的解决方案。

## 特性

- **多集群管理**: 集中管理多个 Kubernetes 集群
- **用户友好界面**: 直观的 Web UI 管理 Kubernetes 资源
- **访问控制**: 基于角色的访问控制 (RBAC)
- **应用商店**: 内置应用目录，快速部署应用
- **监控告警**: 集成 Prometheus 和 Grafana
- **CI/CD 集成**: 支持流水线和 GitOps
- **多云支持**: 支持 AWS、Azure、GCP 等主流云平台

## 快速开始

### 1. 初始化环境

```bash
# 运行初始化脚本（自动生成密码）
./init.sh

# 启动服务
docker compose up -d

# 查看启动日志
docker compose logs -f rancher-server
```

### 2. 访问 Rancher

- **HTTPS访问**: https://your-server-ip
- **HTTP访问**: http://your-server-ip
- **默认用户名**: admin
- **密码**: 在 init.sh 执行后显示的密码

### 3. 首次配置

1. 登录后设置 Server URL
2. 创建或导入 Kubernetes 集群
3. 配置用户和权限
4. 部署应用程序

## 服务组件

| 服务 | 容器名 | 端口 | 说明 |
|------|--------|------|------|
| Rancher Server | rancher-server | 80, 443 | Rancher 管理界面 |
| MySQL | rancher-mysql | 3306 | 数据库服务 |

## 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `MYSQL_ROOT_PASSWORD` | 自动生成 | MySQL root 密码 |
| `MYSQL_PASSWORD` | 自动生成 | MySQL cattle 用户密码 |
| `CATTLE_BOOTSTRAP_PASSWORD` | 自动生成 | Rancher admin 初始密码 |

## 数据持久化

- **data/rancher**: Rancher 应用数据
- **data/mysql**: MySQL 数据库文件
- **data/audit_log**: 审计日志
- **data/certs**: SSL 证书存储

## 常用命令

```bash
# 查看所有服务状态
docker compose ps

# 查看 Rancher 日志
docker compose logs -f rancher-server

# 查看 MySQL 日志
docker compose logs -f rancher-mysql

# 重启服务
docker compose restart rancher-server

# 更新镜像
docker compose pull
docker compose up -d

# 备份数据
docker compose exec rancher-mysql mysqldump -u root -p cattle > rancher_backup.sql

# 重新生成密码
./init.sh --regenerate-secrets
```

## 集群管理

### 创建新集群

1. 点击 "Add Cluster"
2. 选择集群类型（云服务商或自定义）
3. 配置集群参数
4. 运行提供的命令在目标节点上

### 导入现有集群

1. 点击 "Import"
2. 在现有集群中运行提供的 kubectl 命令
3. 集群将自动注册到 Rancher

## 应用部署

### 使用应用商店

1. 选择目标集群和命名空间
2. 进入 "Apps & Marketplace"
3. 选择需要的应用
4. 配置参数并部署

### 使用 YAML 文件

1. 进入 "Workloads"
2. 点击 "Import YAML"
3. 粘贴或上传 YAML 文件
4. 部署到指定命名空间

## 监控和告警

### 启用集群监控

1. 选择集群
2. 点击 "Tools" -> "Monitoring"
3. 安装 Prometheus + Grafana
4. 配置告警规则和通知渠道

### 查看监控数据

1. 进入 "Cluster Explorer"
2. 选择 "Monitoring"
3. 查看 Grafana 仪表板

## 备份恢复

### 数据备份

```bash
# 备份 MySQL 数据
docker compose exec rancher-mysql mysqldump -u root -p cattle > backup.sql

# 备份 Rancher 数据
tar czf rancher_data_backup.tar.gz data/rancher/

# 备份证书
tar czf rancher_certs_backup.tar.gz data/certs/

# 备份审计日志
tar czf rancher_audit_backup.tar.gz data/audit_log/
```

### 数据恢复

```bash
# 恢复 MySQL 数据
docker compose exec -T rancher-mysql mysql -u root -p cattle < backup.sql

# 恢复 Rancher 数据
tar xzf rancher_data_backup.tar.gz

# 恢复证书
tar xzf rancher_certs_backup.tar.gz

# 恢复审计日志
tar xzf rancher_audit_backup.tar.gz
```

## 安全建议

1. **SSL 证书**: 在生产环境中使用有效的 SSL 证书
2. **防火墙**: 限制对 Rancher 的网络访问
3. **密码策略**: 定期更新密码
4. **RBAC**: 配置适当的用户权限
5. **审计日志**: 启用并定期检查审计日志
6. **备份**: 定期备份关键数据

## 故障排除

### 常见问题

1. **无法访问 Rancher UI**
   ```bash
   # 检查服务状态
   docker compose ps

   # 查看日志
   docker compose logs rancher-server
   ```

2. **数据库连接失败**
   ```bash
   # 检查 MySQL 服务
   docker compose logs rancher-mysql

   # 验证数据库连接
   docker compose exec rancher-mysql mysql -u cattle -p cattle
   ```

3. **集群注册失败**
   - 检查网络连接
   - 验证防火墙规则
   - 确认 Server URL 配置正确

### 日志查看

```bash
# Rancher Server 日志
docker compose logs -f rancher-server

# MySQL 日志
docker compose logs -f rancher-mysql

# 系统资源监控
docker stats
```

## 升级指南

```bash
# 备份当前数据
./backup.sh

# 停止服务
docker compose down

# 拉取最新镜像
docker compose pull

# 启动新版本
docker compose up -d

# 检查升级状态
docker compose logs -f rancher-server
```

## 清理命令

```bash
# 停止并删除所有服务和数据
find . -maxdepth 1 ! -name '.' ! -name 'rancher' -exec rm -rf {} +
```

## 参考文档

- [Rancher 官方文档](https://rancher.com/docs/)
- [Kubernetes 文档](https://kubernetes.io/docs/)
- [Docker Compose 文档](https://docs.docker.com/compose/)

## 技术支持

- **官方支持**: https://rancher.com/support/
- **社区论坛**: https://forums.rancher.com/
- **GitHub**: https://github.com/rancher/rancher
- **Slack**: https://slack.rancher.io/