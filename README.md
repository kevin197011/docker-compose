# docker-compose

各服务的 Docker Compose 部署配置，每个子目录独立运行。

持久化数据统一放在 `./data/`，配置文件放在 `./config/`（日志 `./logs/`）。

```bash
cd <service>
python3 bootstrap.py    # 大多数服务的入口
docker compose ps
```

Harbor、GitLab、Forgejo 等配置较复杂，见各自目录下的 README。
