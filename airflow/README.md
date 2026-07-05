# Airflow

Apache Airflow 工作流调度。

## 部署

```bash
cd airflow
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 8080 | HTTP |
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
