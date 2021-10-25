#!/bin/bash

function horizontalLine()
{
    echo -e "\n"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    echo -e $1
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
}

[ -n "${DEBUG}" ] && set -x

IP="$(hostname -I | awk '{print $1}')"

horizontalLine "SEU IP E: $IP"

sed "s/ALTERAR_IP/$IP/g" .env.template > .env

source ./.env

horizontalLine "Baixando as imagens necessárias"

docker-compose pull

horizontalLine "O endereço que será configurado no seu arquivo de hosts será: ${IP} ${GITLAB_URL}"

docker-compose up etchosts

grep ${GITLAB_URL} /etc/hosts

horizontalLine "Iniciando o GIT"

docker-compose up -d > /dev/null

horizontalLine "Esperando a URL ficar online\nEste processo pode levar vários minutos...."

while [ true ]
do
    curl ${GITLAB_URL}/-/readiness --connect-timeout 15 &> /dev/null
    if [[ "$?" -eq 0 ]]; then
            curl ${GITLAB_URL}/users/sign_in --connect-timeout 15 &> /dev/null
            if [[ "$?" -eq 0 ]]; then
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

horizontalLine "Aguarde...."
sleep 60

registro=$(docker-compose exec runner grep -qE "(${GITLAB_URL}|${RUNNER_TOKEN})" /etc/gitlab-runner/config.toml && echo Registrado || echo NaoRegistrado)

if [ "$registro" == "Registrado" ] ; then

    horizontalLine "Runners já configurados"
else

    horizontalLine "Registrando os Runners"

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

fi

horizontalLine "Tudo pronto, abrindo o git"

sleep 3

firefox ${GITLAB_URL}