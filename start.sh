#!/bin/bash

IP="$(hostname -I | awk '{print $1}')"

echo -e "SEU IP E: $IP"

sed "s/ALTERAR_IP/$IP/g" .env.template > .env

source ./.env

echo -e "O endereço que será configurado no seu arquivo de hosts será: ${IP} ${GITLAB_URL}"

echo -e "Iniciando o GIT"

docker-compose up -d

./wait-for-it.sh ${GITLAB_URL}/-/readiness -- echo "GIT ONLINE"

echo -e "Registrando os Runners"

docker-compose exec runner gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_URL}" \
  --registration-token "${RUNNER_TOKEN}" \
  --executor "docker" \
  --docker-image alpine:latest \
  --description "docker-runner" \
  --tag-list "docker,aws" \
  --run-untagged="true" \
  --locked="false" \
  --access-level="not_protected"

echo -e "Tudo pronto, abrindo o git"

sleep 10

firefox ${GITLAB_URL}