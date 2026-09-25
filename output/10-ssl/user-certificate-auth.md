# Аутентификация по сертификату пользователя (mTLS) в Termidesk 7.0

## 1. Выпуск сертификата

На эталонном диспетчере или PKI:

`ash
sudo bash output/10-ssl/generate-user-certificate.sh 'user@corp.example.ru' 365
`

Для браузера/клиента экспортируйте PKCS#12:

`ash
sudo openssl pkcs12 -export -inkey /etc/opt/termidesk-vdi/mtls/client.key \
  -in /etc/opt/termidesk-vdi/mtls/client.crt -certfile /etc/opt/termidesk-vdi/mtls/ca.crt \
  -out user.p12
`

## 2. Termidesk (Apache / termidesk-config)

1. Скопируйте ca.crt, client.crt, client.key в /etc/opt/termidesk-vdi/mtls/.
2. В /opt/termidesk/sbin/termidesk-config → «Сертификаты» → mTLS:
   - MTLS_MODE=on (или equire — см. документацию сборки)
   - пути MTLS_CLIENT_CA, MTLS_CLIENT_CERT, MTLS_CLIENT_KEY
3. Настройте Apache по pache-mtls-snippet.conf (заголовки X-TDSK-SSL-CLIENT-*).
4. Перезапуск служб через termidesk-config.

## 3. Портал администратора

«Аутентификация» → «Домены» → добавьте домен типа **Сертификат X.509** (или mTLS):
- указать поле DN/CN для сопоставления с пользователем;
- привязать домен к группам/политикам.

## 4. Termidesk Connect (опционально)

В CLI Connect: set ssl-profile server <имя> setting mtls true и ca-certs для проверки клиентского сертификата.

Документация: https://termidesk.ru/docs/ru-termidesk-doc/v7.0/documentation/termidesk-settings/settings/replace-ssl-apache.html