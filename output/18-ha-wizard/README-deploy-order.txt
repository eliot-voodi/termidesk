Пошаговое развёртывание HA-кластера Termidesk 7.0
Домен: termidesk.local
VIP: portal.termidesk.local
Эталон: disp1.termidesk.local

1. 01-prepare-environment.sh  -> инфраструктурные узлы
2. 02-postgresql-setup.sh     -> 192.0.2.10
3. 03-rabbitmq-setup.sh       -> 192.0.2.10
4. 04-dispatcher-reference.sh -> 192.0.2.30
5. 05-dispatcher-additional   -> остальные диспетчеры
6. 06-celery-setup.sh -> узлы CeleryMan
7. 07-gateway-setup -> шлюзы
8. 08-nginx-lb-setup.sh -> LB
9. 09-healthcheck.ps1