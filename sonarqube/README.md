# Sonarqube Docker Compose

Sonarqube 服务的 Docker Compose 配置。

## 快速开始

### 使用初始化脚本（推荐）

```bash
# 运行初始化脚本
./init.sh

# 或者仅清理其他项目目录
./init.sh --cleanup
```

### 手动启动

```bash
docker compose up -d
```

## 初始化脚本功能

- **完整初始化**: `./init.sh` - 创建目录结构、设置权限、可选择清理其他项目目录
- **仅清理**: `./init.sh --cleanup` - 清理除了 `sonarqube` 目录之外的所有文件和目录
- **帮助信息**: `./init.sh --help` - 显示使用帮助

## 清理其他目录

使用初始化脚本的清理功能可以清理除了当前 `sonarqube` 目录之外的所有文件和目录：

```bash
./init.sh --cleanup
```

**注意**: 此命令会删除上级目录中除了 `sonarqube` 目录之外的所有文件和目录，执行前会要求用户确认。
