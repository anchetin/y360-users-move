#!/bin/bash

# скрипт расчитан на максимум 1000 пользователей.
token="xxx" # токен приложения directory:read_users directory:write_users 
org_id=xxx # ID организации

if ! command -v pwgen &> /dev/null
then
    echo -e "\npwgen не установлен. Необходим для генерации паролей\n"
    exit 1
fi

if ! command -v jq &> /dev/null
then
    echo -e "\njq не установлен. Необходим для обработки данных в json формате\n"
    exit 1
fi


# получаем список id пользователей.
users_id_list=$(
    curl -X GET -s "https://api360.yandex.net/directory/v1/org/$org_id/users/?page=1&perPage=1000" \
    --header 'Authorization: OAuth '$token \
    --header 'Content-Type: application/json' | \
    jq -r 'del(.page,.pages,.perPage,.total) | .users | map(select(.isRobot == false and (.email | test("@yandex.ru$") | not))) | .[].id'
)

users_changed_list='[]'
for user_id in $users_id_list; do

    password=$(pwgen 20 -1 -n -s)

    response=$(
        curl -X PATCH -s -L "https://api360.yandex.net/directory/v1/org/$org_id/users/$user_id" \
            --header 'Authorization: OAuth '$token \
            --header 'Content-Type: application/json' \
            -d '{
                    "password": "'"${password}"'",
                    "passwordChangeRequired": true
                }'
    )

    changed_user=$(echo "$response" | jq --arg key "password" --arg value "$password" '. += {($key): $value}')
    echo "=== Changed user $(echo "$changed_user" | jq -r '.nickname') ==="
    echo "$changed_user"
    echo "======================="

    users_changed_list=$(echo "$users_changed_list" | jq --argjson obj "$changed_user" '. += [$obj]')

done

echo "$users_changed_list" > pwreset_users_list.json
echo "$users_changed_list" | jq -r '["Email","Password"], (.[] | [.email, .password]) | @csv' > pwreset_users_list.csv
