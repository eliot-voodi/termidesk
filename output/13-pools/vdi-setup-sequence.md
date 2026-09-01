# Последовательность настройки VDI — Termidesk 7.0
# https://termidesk.ru/docs/ru-termidesk-doc/v7.0/documentation/termidesk-settings/pools/add-pool.html

1. Подготовить шаблон ВМ на платформе виртуализации
2. Добавить поставщик ресурсов
3. Создать шаблон РМ в Termidesk
4. Настроить параметры гостевой ОС
5. Добавить протоколы доставки
6. Добавить сети
7. Создать фонд РМ:
   - VDI Pool 01: поставщик=oVirt Provider, шаблон=Win11-VDI-Template, 2-10 РМ, протокол=TERA

8. Назначить группы, протоколы, сети
9. Опубликовать фонд