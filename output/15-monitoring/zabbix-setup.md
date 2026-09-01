# Zabbix — шаблон мониторинга Termidesk 7.0
# https://termidesk.ru/docs/ru-termidesk-doc/v7.0/documentation/termidesk-settings/monitoring-notifications/zabbix.html
# Импортируйте шаблон из документации на сервер: zabbix.termidesk.local

Метрики:
- /api/health/metrics/?key=<METRICS_ACCESS_KEY>
- Инфраструктура -> статус компонентов в портале
- Celery beat/worker health на портах 8103/8104