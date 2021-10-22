#!/bin/bash

[ -n "${DEBUG}" ] && set -x

IP="$(hostname -I | awk '{print $1}')"

echo -e "SEU IP E: $IP"

sed "s/ALTERAR_IP/$IP/g" .env.template > .env

source ./.env

echo -e "Baixando as imagens necessárias"

docker-compose pull

echo -e "O endereço que será configurado no seu arquivo de hosts será: ${IP} ${GITLAB_URL}"

docker-compose up etchosts

grep ${GITLAB_URL} /etc/hosts

echo -e "Iniciando o GIT"

docker-compose up -d > /dev/null

echo -e "Esperando a URL ficar online"
echo -e "Este processo pode levar vários minutos...."

while [ true ]
do
    curl ${GITLAB_URL}/-/readiness --connect-timeout 15 &> /dev/null
    if [[ "$?" -eq 0 ]]; then
            curl ${GITLAB_URL}/users/sign_in --connect-timeout 15 &> /dev/null
            if [[ "$?" -eq 0 ]]; then
                echo "SUCESSO"
                break
            else
                # echo -e "Erro, será realizado nova tentativa"
                sleep 15
            fi
    else
        # echo -e "Erro, será realizado nova tentativa"
        sleep 15
    fi
done

echo -e "Aguarde...."
sleep 30

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

sleep 3

firefox ${GITLAB_URL}