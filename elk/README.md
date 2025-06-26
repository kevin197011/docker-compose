# ELK Stack Docker Compose 部署

## 📖 项目简介

Elasticsearch、Logstash 和 Kibana 日志分析栈

## ✨ 功能特性

- 🚀 一键部署，开箱即用
- 🔧 自动环境检查和初始化
- 📊 健康检查和服务监控
- 🛠️ 完整的数据持久化
- 🔄 支持服务重启和升级
- 📋 详细的日志记录

## 🚀 快速开始

### 方式一：一键部署（推荐）

```bash
# 克隆项目
git clone <repository-url>
cd elk

# 一键部署
./bootstrap.sh
```

### 方式二：分步部署

```bash
# 1. 初始化环境
./bootstrap.sh --init

# 2. 启动服务
docker compose up -d

# 3. 查看状态
docker compose ps
```

## 📋 系统要求

- Docker Engine 20.10+
- Docker Compose 2.0+
- 系统内存: 建议 2GB+
- 磁盘空间: 建议 10GB+

## 🌐 服务端口

- **9200**: ELK Stack 服务端口
- **5601**: ELK Stack 服务端口


## 🔧 配置说明

### 目录结构

```
elk/
├── bootstrap.sh          # 一体化部署脚本
├── compose.yml           # Docker Compose 配置
├── README.md            # 项目文档
├── data/               # 数据目录
├── logs/               # 日志目录
└── config/             # 配置目录
```

### 环境变量

主要的环境变量在 `compose.yml` 文件中定义，可以根据需要进行调整。

## 📊 使用指南

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
docker compose logs -f <service-name>
```

### 停止服务

```bash
# 停止服务
docker compose down

# 停止服务并删除数据卷
docker compose down -v
```

## 🔗 访问地址

服务启动后，可以通过以下地址访问：

- ELK Stack: http://localhost:9200
- ELK Stack: http://localhost:5601


## 🛠️ 故障排除

### 常见问题

1. **端口冲突**
   - 检查端口是否被占用：`netstat -tulpn | grep <port>`
   - 修改 `compose.yml` 中的端口映射

2. **权限问题**
   - 确保当前用户有 Docker 权限：`sudo usermod -aG docker $USER`
   - 重新登录或重启系统

3. **内存不足**
   - 检查系统内存使用：`free -h`
   - 调整 Docker 内存限制

4. **磁盘空间不足**
   - 检查磁盘空间：`df -h`
   - 清理 Docker 镜像：`docker system prune -a`

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
# 1. 停止当前服务
docker compose down

# 2. 拉取最新镜像
docker compose pull

# 3. 重新启动
docker compose up -d
```

### 备份数据

```bash
# 备份数据目录
tar -czf backup-$(date +%Y%m%d).tar.gz data/

# 备份配置文件
cp compose.yml compose.yml.backup
```

## 📚 相关资源

- [官方文档](https://docs.docker.com/compose/)
- [Docker Hub]()
- [GitHub 仓库]()

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](../LICENSE) 文件了解详情。

## ⭐ Star History

如果这个项目对你有帮助，请给它一个星标！

---

**注意**: 首次部署时，某些服务可能需要额外的配置步骤，请参考具体服务的官方文档。
