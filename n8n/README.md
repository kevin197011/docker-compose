# n8n Docker Compose

n8n 工作流自动化平台的 Docker Compose 配置。

## 使用方法

```bash
docker compose up -d
```

## 清理其他目录

如果您需要清理除了当前目录之外的所有其他目录，可以使用以下命令：

```bash
find . -maxdepth 1 ! -name '.' ! -name 'n8n' -exec rm -rf {} +
```

**注意**: 此命令会删除当前目录下除了 `n8n` 目录之外的所有文件和目录，请谨慎使用！