# Termidesk 7.0 — настройка Termidesk Connect (Шлюзы)
# С Termidesk 6.1+ шлюз реализуется через Termidesk Connect Basic
#
# Документация:
#   https://termidesk.ru/docs/ru-connect-doc/v1.3/tech-materials/how-to/config-gateway.html
#   https://termidesk.ru/docs/ru-connect-doc/v1.3/tech-materials/how-to/config-gateway-2.html

Шлюзы в кластере:
  - tdc-gw1.termidesk.local (192.0.2.50:5099)
  - tdc-gw2.termidesk.local (192.0.2.51:5099)

Для каждого шлюза:
  1. Установите Termidesk Connect
  2. Настройте регистрацию в RabbitMQ (coordinatorUrl, coordinatorUser, coordinatorPass)
  3. Настройте websockify на порту 5099 (по умолчанию)
  4. Проверьте healthcheck endpoint

Балансировка websockify — через upstream daas-upstream-ws в nginx (см. nginx-site.conf)
