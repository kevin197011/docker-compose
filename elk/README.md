# ELK

Elasticsearch + Kibana。

## 部署

```bash
cd elk
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 5601 |  |
| 9200 |  |

Elasticsearch :9200，Kibana :5601
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
