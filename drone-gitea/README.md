<!--
 Copyright (c) 2023 kk

 This software is released under the MIT License.
 https://opensource.org/licenses/MIT
-->

## gitea app.ini 新增 webhook 白名单配置

[webhook]
ALLOWED_HOST_LIST = 0.0.0.0, 192.168.56.0/24

## 清理其他目录

如果您需要清理除了当前目录之外的所有其他目录，可以使用以下命令：

```bash
find . -maxdepth 1 ! -name '.' ! -name 'drone-gitea' -exec rm -rf {} +
```

**注意**: 此命令会删除当前目录下除了 `drone-gitea` 目录之外的所有文件和目录，请谨慎使用！
