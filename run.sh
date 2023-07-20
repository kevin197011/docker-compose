# Copyright (c) 2023 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

source /vagrant/.env
cp -avR /vagrant/${COMPOSE_PROJECT_NAME} /tmp/
cd /tmp/${COMPOSE_PROJECT_NAME}
docker compose up -d
docker compose ps
