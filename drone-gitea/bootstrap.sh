# Copyright (c) 2023 kk
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# 9039403607fd01a65fd3372608f185b4420e564b


export HOSTNAME=$(hostname)
export DRONE_VERSION=latest
export DRONE_RUNNER_VERSION=latest
export GITEA_VERSION=latest
export IP_ADDRESS=192.168.56.11
export MINIO_ACCESS_KEY="EXAMPLEKEY"
export MINIO_SECRET_KEY="EXAMPLESECRET"
export GITEA_ADMIN_USER="root"
export DRONE_RPC_SECRET="$(echo ${HOSTNAME} | openssl dgst -md5 -hex)"
export DRONE_USER_CREATE="username:${GITEA_ADMIN_USER},machine:false,admin:true,token:${DRONE_RPC_SECRET}"
export DRONE_GITEA_CLIENT_ID=""
export DRONE_GITEA_CLIENT_SECRET=""
docker-compose up -d

echo ""
echo "Gitea: http://${IP_ADDRESS}:3000/"
echo "Drone: http://${IP_ADDRESS}:3001/"