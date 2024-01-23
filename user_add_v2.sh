#!/bin/bash

token="xxx" # токен приложения directory:read_users directory:write_users ya360_admin:mail_write_routing_rules ya360_admin:mail_read_routing_rules 
org_id=xxx # ID организации

if ! command -v jq &> /dev/null
then
    echo -e "\njq не установлен. Необходим для обработки данных в json формате\n"
    exit 1
fi

temp_json=$(cat users.json)

for (( i=0; i<($(echo "$temp_json" | jq length)); i++ ))
do 
    response=$(curl -X POST -s -L "https://api360.yandex.net/directory/v1/org/$org_id/users" \
    --header 'Authorization: OAuth '$token \
    --header 'Content-Type: application/json' \
    -d "$(jq '.['$i']' users.json)")

    echo "===  $i  ==="
    echo "Responce:"
    echo "$response"

    user_id="$(echo $response | jq -r .id)"
    user_name="$(echo $response | jq -r .nickname)"

    echo "Forwarding rule:"
    curl -X POST -s -L "https://api360.yandex.net/admin/v1/org/$org_id/mail/users/$user_id/settings/user_rules" \
        --header 'Authorization: OAuth '$token \
        --header 'Content-Type: application/json' \
        -d  '{
                "forward": {
                    "address": "'$user_name'@y360.yctesting.eu.org",
                    "ruleName": "test",
                    "withStore": true
                }
            }'
    
    echo
    echo "============"

done


