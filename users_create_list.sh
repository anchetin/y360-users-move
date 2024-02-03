#!/bin/bash

# скрипт расчитан на максимум 1000 пользователей.
token="xxx" # токен приложения права directory:read_users 
org_id=xxx # ID организации
password="xxx" # временный пароль, один для всех пользователей

if ! command -v jq &> /dev/null
then
    echo -e "\njq не установлен. Необходим для обработки данных в json формате\n"
    exit 1
fi

# получаем список пользователей и сразу задаем временный пароль. 
# Если пароль задавать не нужно - удалить
# password: "'$password'",
curl -X GET -s "https://api360.yandex.net/directory/v1/org/$org_id/users/?page=1&perPage=1000" \
--header 'Authorization: OAuth '$token \
--header 'Content-Type: application/json' | jq 'del(.page,.pages,.perPage,.total)' | jq '
.[] | map(select(.isRobot == false)) | del(.[] | select(.email | test("@yandex.ru$"))) | map({
      about,
      birthday,
      contacts: [],
      departmentId,
      gender,
      isAdmin,
      language,
      name,
      nickname,
      password: "'$password'",
      timezone
})' > users.json
