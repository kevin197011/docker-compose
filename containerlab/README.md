# Containerlab

在 Docker 中运行 [Containerlab](https://containerlab.dev/) CLI（官方 Container 模式），用于编排容器化网络实验拓扑。

参考：[Installation → Container](https://containerlab.dev/install/#container)

## 要求

- Linux 宿主机 + Docker（`network_mode: host`、netns 挂载需要 Linux）
- macOS 仅作开发机时，请在 Linux VM/服务器上运行

## 部署

```bash
cd containerlab
python3 bootstrap.py          # 进入 clab 交互 shell
python3 bootstrap.py deploy labs/example.clab.yml
```

等价于官方命令：

```bash
docker run --rm -it --privileged \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/run/netns:/var/run/netns \
  -v /etc/hosts:/etc/hosts \
  -v /var/lib/docker/containers:/var/lib/docker/containers \
  --pid=host \
  -v $(pwd):$(pwd) -w $(pwd) \
  ghcr.io/srl-labs/clab bash
```

## 目录

```
containerlab/
├── compose.yml          # clab 运行容器
├── bootstrap.py
├── labs/                # 拓扑文件 (*.clab.yml)
│   └── example.clab.yml
├── data/
├── logs/
└── config/
```

## 常用命令（在 clab shell 内）

```bash
clab deploy -t labs/example.clab.yml
clab inspect -t labs/example.clab.yml
clab destroy -t labs/example.clab.yml
clab graph -t labs/example.clab.yml
```

## 运维

```bash
python3 bootstrap.py shell
python3 bootstrap.py deploy labs/example.clab.yml
python3 bootstrap.py down      # clab destroy --all
```

镜像版本可在 `.env` 设置 `CLAB_IMAGE`，例如 `ghcr.io/srl-labs/clab:0.72.0`。
