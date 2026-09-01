Termidesk VDI 7.0 — порядок развёртывания отказоустойчивого кластера
Тип: standard
Дата генерации: 2026-08-28 19:41

1. 01-postgresql-setup.sh     — на узле СУБД (192.0.2.10)
2. 02-rabbitmq-setup.sh       — на узле RabbitMQ (192.0.2.10)
3. 03-dispatcher-reference.md — первый диспетчер (disp1.termidesk.local)
4. 04-dispatcher-additional.md — остальные диспетчеры
5. 05-celery-setup.sh         — менеджеры рабочих мест (если standard)
6. 06-gateway-setup.md        — Termidesk Connect шлюзы
7. 07-nginx-lb-setup.sh       — балансировщик (portal.termidesk.local)
8. 08-healthcheck.ps1         — проверка с Windows

Важно:
- Используйте чистую БД без записей Termidesk
- Скопируйте /etc/opt/termidesk-vdi с эталонного узла на все остальные
- OpenBao для HA должен быть отказоустойчивым
- Синхронизация времени (NTP) на всех узлах обязательна

Документация: https://termidesk.ru/docs/ru-termidesk-doc/v7.0/documentation/termidesk-install/install-delete/alse.html