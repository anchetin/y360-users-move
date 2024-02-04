#!/bin/bash

# скрипт расчитан на максимум 1000 пользователей.
# токен приложения 
#     directory:read_users 
#     directory:write_users 
#     directory:read_groups 
#     directory:write_groups 
#     опционально:
#     ya360_admin:mail_write_routing_rules 
#     ya360_admin:mail_read_routing_rules
token="xxx"
org_id=xxx # ID организации
temp_domain="xxx" # временный домен


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
    echo "Response:"
    echo "$response"

    # # откомментировать блок если нужно правило для переадресации
    # user_id="$(echo $response | jq -r .id)"
    # user_name="$(echo $response | jq -r .nickname)"
    # echo "Forwarding rule:" 
    # curl -X POST -s -L "https://api360.yandex.net/admin/v1/org/$org_id/mail/users/$user_id/settings/user_rules" \
    #     --header 'Authorization: OAuth '$token \
    #     --header 'Content-Type: application/json' \
    #     -d  '{
    #             "forward": {
    #                 "address": "'$user_name'@'$temp_domain'",
    #                 "ruleName": "test",
    #                 "withStore": true
    #             }
    #         }'
    # # конец комментария
    
    echo
    echo "============"

done


user_list=$(
    curl -X GET -s "https://api360.yandex.net/directory/v1/org/$org_id/users/?page=1&perPage=1000" \
        --header 'Authorization: OAuth '$token \
        --header 'Content-Type: application/json' | jq 'del(.page,.pages,.perPage,.total)' | jq '
        .[] | map(select(.isRobot == false)) | del(.[] | select(.email | test("@yandex.ru$")))'
)

group_list="$(cat groups.json)"

for (( i=0; i<($(echo "$group_list" | jq length)); i++ )); do

    echo "===  $i  ==="

    group_json="$(echo "$group_list" | jq '.['$i']')"

    # Create a new array for members and admins
    new_members=()
    new_admins=()

    # Loop over each member
    for row in $(echo "${group_json}" | jq -r '.members[] | @base64'); do
        # Get the member from the row
        member=$(echo "${row}" | base64 --decode)

        # Get the nickname of the member
        nickname=$(echo "${member}" | jq -r '.nickname')

        # Look up the id from $user_list
        id=$(echo "$user_list" | jq -r --arg nickname "${nickname}" '.[] | select(.nickname==$nickname) | .id')

        if [ "${id}" != "" ]; then
            member=$(echo "${member}" | jq --arg id "${id}" '.id = $id | del(.nickname)')
            new_members+=("${member}")
        else
            echo "Failed to add user $nickname in group."
        fi
    done

    for nickname in $(echo "${group_json}" | jq -r '.adminIds[]'); do
        # Look up the nickname from $user_list
        id=$(echo "$user_list" | jq -r --arg nickname "${nickname}" '.[] | select(.nickname==$nickname) | .id')

        if [ "$id" != "" ]; then
            new_admins+=("$id")
        fi
    done

    # Replace the members array in the group json with the new members array
    group_json=$(echo ${group_json} | jq --argjson new_members "$(echo ${new_members[@]} | jq -s .)" '.members = $new_members')

    if [ -n "${new_admins}" ]; then
        new_admins_json=$(printf '%s\n' "${new_admins[@]}" | jq -R . | jq -s .)
        group_json=$(echo "${group_json}" | jq --argjson new_admins_json "${new_admins_json}" '.adminIds = $new_admins_json')
    fi

    # echo $group_json | jq
    response=$(curl -X POST -s -L "https://api360.yandex.net/directory/v1/org/$org_id/groups" \
    --header 'Authorization: OAuth '$token \
    --header 'Content-Type: application/json' \
    -d "$group_json"
    )

    echo "Response:"
    echo "$response"
    echo "============"


done