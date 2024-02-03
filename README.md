# y360-users-move

### users_create_list.sh
Выгружает список пользователей из организации и подготавливает для загрузки в другую.  
Токен приложения. Требуются права directory:read_users 
```
token="xxx"
```
ID организации
```
org_id=xxx
```
Временный пароль, один для всех пользователей
```
password="xxx"
```


### users_create_from_list.sh
Создает пользователей из выгруженного ранее списка в другой организации.  
Опционально возможно создание правила переадресации внутри домена.  
  
Токен приложения. Требуются права  
directory:read_users   
directory:write_users  
ya360_admin:mail_write_routing_rules  
ya360_admin:mail_read_routing_rules 
```
token="xxx"
```
ID организации
```
org_id=xxx
```
Домен в котором создавать правило переадресации
```
temp_domain="xxx"
```

### users_reset_passw.sh
Для каждого пользователя устанавливает случайный пароль, устанавливает флаг для задания пароля при первом входе.  
Выгружает итоговый список пользователей с паролем в pwreset_users_list.csv  
  
Токен приложения. Требуются права  
directory:read_users   
directory:write_users  
```
token="xxx"
```
ID организации
```
org_id=xxx
```
