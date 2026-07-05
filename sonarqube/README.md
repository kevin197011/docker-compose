# SonarQube

SonarQube 代码质量分析。

## 部署

```bash
cd sonarqube
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 9000 | HTTP |

http://localhost:9000
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
