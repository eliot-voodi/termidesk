# Смена пароля PostgreSQL для Termidesk

## 1. На узле PostgreSQL

`ash
sudo bash output/03-database/02-change-password.sh 'НовыйСложныйПароль'
`

## 2. На всех узлах Termidesk (диспетчеры, CeleryMan)

1. Отредактируйте /etc/opt/termidesk-vdi/termidesk.conf — параметр DBPASS.
2. Либо выполните /opt/termidesk/sbin/termidesk-config → «Настройка подключения к СУБД».
3. Перезапустите службы: sudo systemctl restart termidesk-vdi.

## 3. OpenBao (если SECRETS_STORAGE_METHOD=openbao)

Обновите секрет БД по пути из SECRETS_OPENBAO_DB_PATH, затем перезапустите компоненты.

## 4. Панель администратора (Windows)

Обновите database.password в config/termidesk-settings.json, чтобы при перегенерации скриптов не подставился старый пароль.

Текущие параметры: пользователь $(@{clusterMode=cluster; host1=192.0.2.10; host2=192.0.2.11; host3=192.0.2.12; port=5432; name=termidesk; user=termideskdb; password=; pgHbaNetwork=192.0.2.0/24; maxConnections=100; ssl=False}.user), БД $(@{clusterMode=cluster; host1=192.0.2.10; host2=192.0.2.11; host3=192.0.2.12; port=5432; name=termidesk; user=termideskdb; password=; pgHbaNetwork=192.0.2.0/24; maxConnections=100; ssl=False}.name), хост $(@{clusterMode=cluster; host1=192.0.2.10; host2=192.0.2.11; host3=192.0.2.12; port=5432; name=termidesk; user=termideskdb; password=; pgHbaNetwork=192.0.2.0/24; maxConnections=100; ssl=False}.host1):5432.