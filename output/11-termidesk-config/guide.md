# termidesk-config — интерактивная утилита Termidesk 7.0
cd /opt/termidesk/sbin/
sudo ./termidesk-config

Доступные разделы:
- Режим работы узла (TERMIDESK_FARM_MODE)
- Роли узла (NODE_ROLES): ADMIN, USER, CELERYMAN, TERMQ
- Способ хранения паролей (config/hvac/openbao)
- Тип установки СУБД (DB_CLUSTER_MODE)
- Настройка подключения к СУБД и RabbitMQ
- TermideskMQ клиент (TMQ_*)
- Fluentd / журналирование
- Сертификаты mTLS, Health Check, JWT Aggregator
- Перезапуск служб

После изменений всегда: «Перезапуск служб»