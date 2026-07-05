# go-ldap-admin

[go-ldap-admin](https://github.com/eryajf/go-ldap-admin) LDAP 管理平台，含 MySQL、OpenLDAP、phpLDAPadmin。

## 部署

```bash
cd go-ldap-admin
python3 bootstrap.py
```

## 端口

| 端口 | 说明 |
|------|------|
| 8888 | go-ldap-admin Web |
| 8091 | phpLDAPadmin |
| 389 | LDAP |
| 3306 | MySQL |

## 运维

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f
```

数据目录：`./data/`。默认 LDAP 域 `eryajf.net`，管理员密码见 `compose.yml`。
