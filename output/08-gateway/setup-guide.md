# Termidesk Connect — настройка шлюзов Termidesk VDI 7.0
# https://termidesk.ru/docs/ru-connect-doc/v1.3/tech-materials/how-to/config-gateway.html

1. Установите Termidesk Connect Basic на каждый узел шлюза
2. Скопируйте gateway.yaml в /etc/opt/termidesk-gateway/
3. Зарегистрируйте шлюз в RabbitMQ (coordinatorUrl)
4. Проверьте healthcheck: curl -k https://<gw>:443/api/health

Шлюзы кластера:
- tdc-gw1.termidesk.local (192.0.2.50:5099)
- tdc-gw2.termidesk.local (192.0.2.51:5099)
