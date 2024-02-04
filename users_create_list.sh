#!/bin/bash

# скрипт расчитан на максимум 1000 пользователей.
token="xxx" # токен приложения права directory:read_users directory:read_groups 
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
      departmentId: 1,
      gender,
      isAdmin,
      language,
      name,
      nickname,
      password: "'$password'",
      timezone
})' > users.json

user_list=$(
    curl -X GET -s "https://api360.yandex.net/directory/v1/org/$org_id/users/?page=1&perPage=1000" \
        --header 'Authorization: OAuth '$token \
        --header 'Content-Type: application/json' | jq 'del(.page,.pages,.perPage,.total)' | jq '
        .[] | map(select(.isRobot == false)) | del(.[] | select(.email | test("@yandex.ru$")))'
)

group_list=$(
    curl -X GET -s "https://api360.yandex.net/directory/v1/org/$org_id/groups/?page=1&perPage=1000" \
    --header 'Authorization: OAuth '$token \
    --header 'Content-Type: application/json' 
)

group_list=$(echo $group_list | jq '.groups | map(select(.type == "generic"))')
changed_group_list='[]'

for (( i=0; i<($(echo "$group_list" | jq length)); i++ )); do
    
    group_json="$(echo "$group_list" | jq '.['$i']')"

    # Create a new array for members and admins
    new_members=()
    new_admins=()

    # Loop over each member
    for row in $(echo "${group_json}" | jq -r '.members[] | @base64'); do
        # Get the member from the row
        member=$(echo "${row}" | base64 --decode)

        # Get the id of the member
        id=$(echo "${member}" | jq -r '.id')

        # Look up the nickname from $user_list
        nickname=$(echo "$user_list" | jq -r --arg id "${id}" '.[] | select(.id==$id) | .nickname')

        # If the nickname is not null, replace the id with the nickname in the member object
        # and add the member object to the new members array
        if [ "${nickname}" != "" ]; then
            member=$(echo "${member}" | jq --arg nickname "${nickname}" '. + {"nickname": $nickname}')
            new_members+=("${member}")
        else
            echo "User with ID $id was skipped."
        fi
    done

    for id in $(echo "${group_json}" | jq -r '.adminIds[]'); do
        # Look up the nickname from $user_list
        nickname=$(echo "$user_list" | jq -r --arg id "${id}" '.[] | select(.id==$id) | .nickname')

        # If the nickname is not null, replace the id with the nickname in the member object
        # and add the member object to the new members array
        if [ "${nickname}" != "" ]; then
            new_admins+=("$nickname")
        fi
    done


    # Replace the members array in the group json with the new members array
    group_json=$(echo ${group_json} | jq --argjson new_members "$(echo ${new_members[@]} | jq -s .)" '.members = $new_members')

    if [ -n "${new_admins}" ]; then
        new_admins_json=$(printf '%s\n' "${new_admins[@]}" | jq -R . | jq -s .)
        group_json=$(echo "${group_json}" | jq --argjson new_admins_json "${new_admins_json}" '.adminIds = $new_admins_json')
    fi

    changed_group_list=$(echo ${changed_group_list} | jq --argjson group_json "${group_json}" '. += [$group_json]')

done



echo "${changed_group_list}" | jq 'map({
    adminIds: .adminIds,
    description: .description,
    label: .label,
    members: .members,
    name: .name
})' > groups.json

