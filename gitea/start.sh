#!/bin/bash

# 获取本机IP地址的函数
get_local_ip() {
    # 尝试多种方式获取本机IP地址
    local ip=""

    # 方法1: 通过route命令获取默认网关对应的IP
    if command -v route >/dev/null 2>&1; then
        ip=$(route get default 2>/dev/null | grep interface | awk '{print $2}' | xargs ifconfig 2>/dev/null | grep 'inet ' | head -1 | awk '{print $2}')
    fi

    # 方法2: 通过ip命令获取
    if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    fi

    # 方法3: 通过ifconfig获取第一个非回环地址
    if [[ -z "$ip" ]] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | sed 's/addr://')
    fi

    # 方法4: macOS 特定方法
    if [[ -z "$ip" ]] && [[ "$OSTYPE" == "darwin"* ]]; then
        ip=$(ifconfig en0 2>/dev/null | grep 'inet ' | awk '{print $2}')
        if [[ -z "$ip" ]]; then
            ip=$(ifconfig en1 2>/dev/null | grep 'inet ' | awk '{print $2}')
        fi
    fi

    echo "$ip"
}

# 设置默认值
USE_EXTERNAL_IP=${USE_EXTERNAL_IP:-false}
GITEA_PORT=${GITEA_PORT:-3000}

# 如果启用了外部IP，动态获取并更新.env文件
if [[ "$USE_EXTERNAL_IP" == "true" ]]; then
    echo "正在获取本机IP地址..."
    LOCAL_IP=$(get_local_ip)

    if [[ -n "$LOCAL_IP" ]]; then
        echo "检测到本机IP: $LOCAL_IP"

        # 更新.env文件中的GITEA_INSTANCE_URL
        if [[ -f .env ]]; then
            # 备份原始文件
            cp .env .env.bak

            # 更新GITEA_INSTANCE_URL
            sed -i.tmp "s|^GITEA_INSTANCE_URL=.*|GITEA_INSTANCE_URL=http://${LOCAL_IP}:${GITEA_PORT}|" .env
            rm -f .env.tmp

            echo "已更新 GITEA_INSTANCE_URL 为: http://${LOCAL_IP}:${GITEA_PORT}"
        else
            echo "警告: .env 文件不存在"
        fi
    else
        echo "警告: 无法获取本机IP地址，使用默认配置"
    fi
fi

# 启动Docker Compose
echo "启动Gitea服务..."
docker compose up -d

echo "服务启动完成!"
echo ""
echo "访问地址:"
if [[ "$USE_EXTERNAL_IP" == "true" && -n "$LOCAL_IP" ]]; then
    echo "  外部访问: http://${LOCAL_IP}:${GITEA_PORT}"
fi
echo "  本地访问: http://localhost:${GITEA_PORT}"
echo ""
echo "查看服务状态: docker compose ps"
echo "查看日志: docker compose logs -f"