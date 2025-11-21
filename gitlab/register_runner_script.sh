#!/bin/bash

# 等待 GitLab 启动
echo "等待 GitLab 启动..."
until curl -s -f "http://localhost:8000/-/readiness" > /dev/null 2>&1; do
  echo "GitLab 还未就绪，继续等待..."
  sleep 10
done

echo "GitLab 已就绪！"
echo "请按照以下步骤手动注册 Runner："
echo ""
echo "1. 打开浏览器访问: http://localhost:8000"
echo "2. 使用 root 用户登录（密码在 .env 文件中）"
echo "3. 访问: http://localhost:8000/admin/runners"
echo "4. 复制 registration token"
echo "5. 运行以下命令注册 Runner："
echo ""
echo "   docker exec -it gitlab-runner gitlab-runner register \\"
echo "     --url http://localhost:8000 \\"
echo "     --registration-token YOUR_TOKEN_HERE \\"
echo "     --executor docker \\"
echo "     --docker-image alpine:latest \\"
echo "     --description 'Docker Runner' \\"
echo "     --tag-list 'docker,shared' \\"
echo "     --run-untagged \\"
echo "     --locked=false"
echo ""
echo "6. 注册完成后重启 Runner 容器："
echo "   docker-compose restart gitlab-runner"