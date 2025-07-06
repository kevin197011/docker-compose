# Nacos Docker Compose

本目录用于本地快速部署 Nacos 服务。

## 使用方法

1. 启动服务：
   ```sh
   ./bootstrap.sh
   ```
2. 访问 Nacos 控制台：
   - http://localhost:8848/nacos

## 目录结构
- compose.yml         # Docker Compose 配置
- bootstrap.sh        # 一键启动脚本
- data/               # Nacos 数据目录
- logs/               # 日志目录
- conf/               # 配置目录
