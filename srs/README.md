# SRS (Simple Realtime Server) Docker Compose 部署

## 📖 项目简介

SRS 是一个简单高效的实时视频服务器，支持 RTMP、WebRTC、HLS、HTTP-FLV 等多种流媒体协议。

## ✨ 功能特性

- 🚀 一键部署，开箱即用
- 📺 支持 RTMP 推流和拉流
- 🌐 支持 HTTP-FLV、HLS 播放
- 🔧 灵活的配置管理
- 📊 完整的日志记录
- 🔄 支持服务重启和升级

## 🚀 快速开始

### 方式一：一键部署（推荐）

```bash
# 进入目录
cd srs

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

- **1935**: RTMP 端口（推流/拉流）
- **1985**: HTTP API 端口（管理接口）
- **8080**: HTTP 端口（HLS/HTTP-FLV 播放）
- **8000/udp**: UDP 端口
- **10080/udp**: UDP 端口

## 🔧 配置说明

### 目录结构

```
srs/
├── bootstrap.sh          # 一体化部署脚本
├── compose.yml           # Docker Compose 配置
├── README.md            # 项目文档
└── ~/srs6/              # SRS 配置和数据目录
    ├── conf/            # 配置文件目录
    └── objs/            # 对象文件目录
```

### 配置文件位置

SRS 的配置文件位于 `~/srs6/conf/srs.conf`，可以根据需要进行修改。

**注意**: 首次使用前，请确保 `~/srs6/conf` 和 `~/srs6/objs` 目录存在，或者修改 `compose.yml` 中的卷映射路径。

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
docker compose logs -f srs
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

- **RTMP 推流地址**: `rtmp://localhost:1935/live/stream`
- **HTTP API**: `http://localhost:1985/api/v1/`
- **HLS 播放地址**: `http://localhost:8080/live/stream.m3u8`
- **HTTP-FLV 播放地址**: `http://localhost:8080/live/stream.flv`

## 📺 推流示例

### 使用 FFmpeg 推流

```bash
# RTMP 推流
ffmpeg -re -i input.mp4 -c copy -f flv rtmp://localhost:1935/live/stream

# 使用摄像头推流
ffmpeg -f avfoundation -i "0" -c:v libx264 -preset ultrafast -f flv rtmp://localhost:1935/live/stream
```

### 使用 OBS 推流

1. 打开 OBS Studio
2. 设置 -> 推流
3. 服务: 自定义
4. 服务器: `rtmp://localhost:1935/live`
5. 推流密钥: `stream`
6. 开始推流

## 🛠️ 故障排除

### 常见问题

1. **端口冲突**
   - 检查端口是否被占用：`netstat -tulpn | grep <port>`
   - 修改 `compose.yml` 中的端口映射

2. **配置文件不存在**
   - 确保 `~/srs6/conf/srs.conf` 文件存在
   - 可以从 SRS 官方仓库获取默认配置文件

3. **权限问题**
   - 确保当前用户有 Docker 权限：`sudo usermod -aG docker $USER`
   - 重新登录或重启系统

4. **内存不足**
   - 检查系统内存使用：`free -h`
   - 调整 Docker 内存限制

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
# 备份配置目录
tar -czf backup-$(date +%Y%m%d).tar.gz ~/srs6/conf/

# 备份配置文件
cp compose.yml compose.yml.backup
```

## 📚 相关资源

- [SRS 官方文档](https://ossrs.net/lts/zh-cn/docs/v4/doc/getting-started)
- [SRS GitHub 仓库](https://github.com/ossrs/srs)
- [Docker Hub - SRS](https://hub.docker.com/r/ossrs/srs)

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](../LICENSE) 文件了解详情。

---

**注意**: 首次部署时，请确保 `~/srs6/conf` 和 `~/srs6/objs` 目录存在，或者根据需要修改 `compose.yml` 中的卷映射路径。

