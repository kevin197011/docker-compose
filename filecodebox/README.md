# FileCodeBox

[FileCodeBox](https://github.com/vastsa/FileCodeBox) 文件快传服务（`lanol/filecodebox`）。

## 部署

```bash
cd filecodebox
python3 bootstrap.py
```

## 端口

| 端口 | 说明 |
|------|------|
| 12345 | Web |

## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/filecodebox`。
