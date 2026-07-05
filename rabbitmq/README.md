# RabbitMQ

RabbitMQ 消息队列（含管理界面）。

## 部署

```bash
cd rabbitmq
python3 bootstrap.py
```


## 端口

| 端口 | 说明 |
|------|------|
| 5672 | AMQP |
| 15672 | 管理界面 |

管理界面 http://localhost:15672
## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。
