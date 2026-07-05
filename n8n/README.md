# n8n

n8n 工作流自动化。

## 部署

```bash
cd n8n
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 5678 | Web |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
