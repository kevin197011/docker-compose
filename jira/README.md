# Jira

Jira 10.7.3（`haxqer/jira`）+ PostgreSQL 15，可选 Nginx SSL。

## 部署

```bash
cd jira
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 8080 | Web |

编辑 `.env.example` 后 bootstrap 会渲染 nginx/server 配置。
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
