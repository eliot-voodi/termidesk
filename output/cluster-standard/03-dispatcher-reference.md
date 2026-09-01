# Termidesk 7.0 — Первый (эталонный) Универсальный диспетчер
# Документация: https://termidesk.ru/docs/ru-termidesk-doc/v7.0/documentation/termidesk-install/install-delete/alse.html

## Параметры установки (termidesk-vdi installer / termidesk-config)

TERMIDESK_FARM_MODE = dispatcher
NODE_ROLES = ADMIN,USER
NODE_NAME = <уникальное_имя_узла>

## СУБД
DB_CLUSTER_MODE = cluster
DBHOST  = 192.0.2.10
DBHOST2 = 192.0.2.11
DBHOST3 = 192.0.2.12
DBPORT  = 5432
DBNAME  = termidesk
DBUSER  = termideskdb

## RabbitMQ
RABBITMQ_URL = amqp://admin:<password>@192.0.2.10:5672/

## Команды
sudo apt install -y termidesk-vdi
cd /opt/termidesk/sbin && sudo ./termidesk-config
# Выберите «Перезапуск служб» после изменений


После установки:
  sudo scp -r /etc/opt/termidesk-vdi admin@<целевой_хост>:/home/admin/

Эталонный узел: disp1.termidesk.local (192.0.2.30)
