# Смена пароля RabbitMQ для Termidesk

## 1. На узле RabbitMQ

`ash
sudo bash output/04-rabbitmq/02-change-password.sh 'НовыйСложныйПароль'
`

## 2. На диспетчерах и шлюзах

Обновите в /etc/opt/termidesk-vdi/termidesk.conf:

- RABBITMQ_PASS
- coordinatorPass (если шлюз использует ту же учётку)

Либо через 	ermidesk-config → «Настройка подключения к RabbitMQ».

Перезапуск: sudo systemctl restart termidesk-vdi (диспетчеры) и служба Connect (шлюзы).

## 3. coordinatorUrl

Если пароль в URL (mqp://user:pass@host:5672/), обновите URL в конфиге шлюза.

## 4. Панель (Windows)

Обновите abbitmq.password и gateway.coordinatorPass в config/termidesk-settings.json.

Текущие параметры: пользователь $(@{brokerType=rabbitmq; host=192.0.2.10; port=5672; managementPort=15672; user=admin; password=; vhost=/; ssl=False}.user), vhost $(@{brokerType=rabbitmq; host=192.0.2.10; port=5672; managementPort=15672; user=admin; password=; vhost=/; ssl=False}.vhost), хост $(@{brokerType=rabbitmq; host=192.0.2.10; port=5672; managementPort=15672; user=admin; password=; vhost=/; ssl=False}.host):5672.