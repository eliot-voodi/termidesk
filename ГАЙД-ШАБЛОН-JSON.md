# Гайд: заполнение JSON-шаблона HA-кластера

Шаблон: `config/ha-cluster.template.json`  
Рабочий файл после импорта: `config/termidesk-settings.json`  
Гайд HTML: `ГАЙД-ШАБЛОН-JSON.html`

---

## 1. Зачем это нужно

Вместо долгого мастера **[18] → [1]** можно:

1. Скопировать шаблон.
2. Заполнить все поля `__ЗАПОЛНИТЕ__` в редакторе.
3. Запустить панель с этим JSON — скрипты HA сгенерируются сразу.

Подходит для повторных развёртываний и передачи параметров коллегам без интерактивного опроса.

---

## 2. Быстрый старт

### Шаг A — копия шаблона

```powershell
cd C:\path\to\termidesk
Copy-Item .\config\ha-cluster.template.json .\config\my-ha-cluster.json
notepad .\config\my-ha-cluster.json
```

Или из меню: **[18] → [4] → [1]**.

### Шаг B — заполнить файл

Замените **все** вхождения `__ЗАПОЛНИТЕ...__` на реальные значения.  
Пустые строки `""` допустимы только там, где поле необязательно (см. таблицу ниже).

Сохраните файл в **UTF-8**. JSON должен оставаться валидным (запятые, кавычки, без комментариев `//`).

### Шаг C — запуск с предзаполненным JSON

**Вариант 1 — импорт и меню HA:**

```powershell
.\Start-TermideskMenu.ps1 -SettingsFile .\config\my-ha-cluster.json -HaWizard -Force
```

**Вариант 2 — импорт + сразу сгенерировать скрипты + меню:**

```powershell
.\Start-TermideskMenu.ps1 -SettingsFile .\config\my-ha-cluster.json -GenerateHa -HaWizard -Force
```

**Вариант 3 — только генерация, без меню:**

```powershell
.\Start-TermideskMenu.ps1 -SettingsFile .\config\my-ha-cluster.json -GenerateHa -SkipMenu -Force
```

**Вариант 4 — из меню без параметров CLI:**

1. `.\Start-TermideskMenu.ps1`
2. **[18] → [4]** — загрузить JSON
3. **[3]** — сгенерировать скрипты
4. Шаги развёртывания **1…9**

Параметр **`-Force`** — перезаписать `termidesk-settings.json` без вопроса.

---

## 3. Параметры командной строки

| Параметр | Назначение |
|----------|------------|
| `-SettingsFile <путь>` | Импорт JSON в `config/termidesk-settings.json` |
| `-HaWizard` | После старта открыть меню **[18]** |
| `-GenerateHa` | Сразу сгенерировать `output/18-ha-wizard/` |
| `-SkipMenu` | Не показывать главное меню (обычно с `-GenerateHa`) |
| `-Force` | Не спрашивать подтверждение перезаписи настроек |

Путь может быть относительным от каталога `Start-TermideskMenu.ps1`.

---

## 4. Как заполнять секции шаблона

Плейсхолдеры вида `__ЗАПОЛНИТЕ__` / `__ЗАПОЛНИТЕ_IP__` — **обязательно заменить**.  
После импорта меню **[18] → [4] → [3]** или CLI проверят, что плейсхолдеров не осталось.

### 4.1. `environment`

| Поле | Обязательно | Пример / пояснение |
|------|-------------|-------------------|
| `domain` | да | `corp.example.ru` |
| `ntpServer` | да | IP или FQDN NTP |
| `termideskRepo` | да | URL репозитория Termidesk 7.0 |
| `astraRepo` | нет | строка `sources.list` или `""` |

### 4.2. `ssh`

| Поле | Обязательно | Пример |
|------|-------------|--------|
| `user` | да | учётка с sudo на Linux |
| `port` | да | `22` |
| `keyPath` | нет | `C:\Users\admin\.ssh\id_rsa` или `""` |

### 4.3. `portal`

| Поле | Обязательно | Пример |
|------|-------------|--------|
| `url` | да | `https://disp1.corp.example.ru` |
| `adminUser` / `adminPassword` | да | учётка администратора Termidesk |
| `verifySsl` | — | `false` на стенде с self-signed |

### 4.4. `database`

| Поле | Обязательно | Пример |
|------|-------------|--------|
| `clusterMode` | да | `cluster` или `single` |
| `host1` | да | IP/FQDN master (или единственного узла) |
| `host2` / `host3` | нет | доп. узлы для перебора Termidesk |
| `port` | да | `5432` |
| `name` / `user` / `password` | да | БД приложения |
| `pgHbaNetwork` | да | CIDR, напр. `10.10.0.0/24` |

### 4.5. `rabbitmq`

| Поле | Обязательно | Пример |
|------|-------------|--------|
| `brokerType` | да | `rabbitmq` |
| `host` / `port` | да | хост и `5672` |
| `user` / `password` / `vhost` | да | часто vhost `/` |
| `managementPort` | нет | `15672` |

### 4.6. `cluster.deploymentType`

- `standard` — нужны `celeryManagers` (≥ 2)
- `minimal` — Celery на диспетчерах; `dispatcher.nodeRoles` = `ADMIN,USER,CELERYMAN`, массив celery можно оставить пустым `[]`

### 4.7. Узлы: `dispatchers`, `celeryManagers`, `gateways`, `loadBalancers.nodes`

Для каждого узла заполните `name`, `fqdn`, `ip`.

**Диспетчеры:** минимум 2; у эталона `"isReference": true` (ровно один).  
Имена `referenceNode` и `dispatcher.nodeName` должны совпадать с эталоном.

**Шлюзы:** минимум 2; у каждого `port` (websockify, часто `5099`).

**LB:** минимум 1; `loadBalancers.fqdn` = VIP FQDN для пользователей.

### 4.8. `cluster.tls` (пути только Linux!)

| Поле | Значение |
|------|----------|
| `mode` | `provided` (свои cert) или `selfsigned` |
| `certPath` / `keyPath` | пути **на балансировщике**, напр. `/etc/ssl/certs/portal.crt` |
| `dhparamPath` | обычно `/etc/nginx/dhparam.pem` |
| `dnsResolverPrimary` | IP вашего DNS |
| `certSubject` | для selfsigned = VIP FQDN |

**Нельзя** писать `C:\...` — nginx на Linux эти пути не читает.

Как создать dhparam — см. `НАСТРОЙКА-КЛАСТЕРА.html`.

### 4.9. `cluster.nginx`

Обычно можно оставить значения шаблона:

- `listenHttp`: `0.0.0.0:80`
- `listenHttps`: `0.0.0.0:443 ssl` (слово `ssl` уже внутри значения)
- `dispatcherPort`: `443`
- `proxyTimeout`: `1000`
- каталоги snippets — стандартные для nginx на Astra/Debian

### 4.10. `gateway`

| Поле | Пример |
|------|--------|
| `coordinatorUrl` | `amqp://rmquser@10.10.0.5:5672/` |
| `coordinatorUser` / `coordinatorPass` | те же, что у RabbitMQ (или отдельные) |
| `healthCheckPath` | `/api/health` |

### 4.11. `monitoring`

| Поле | Обязательно |
|------|-------------|
| `healthCheckAccessKey` | да — придумайте длинный секретный ключ |
| `metricsAccessKey` | нет |

### 4.12. `openbao`

Если не используете: `"enabled": false`, остальные поля можно оставить пустыми.  
Если используете: `enabled: true` и заполните url, roleId, пути секретов; `cluster.secretsStorage` = `openbao`.

---

## 5. Проверка перед генерацией

```powershell
.\Start-TermideskMenu.ps1 -SettingsFile .\config\my-ha-cluster.json -Force -SkipMenu
# затем в другой сессии меню [18]→[4]→[3]
# или сразу:
.\Start-TermideskMenu.ps1 -SettingsFile .\config\my-ha-cluster.json -GenerateHa -SkipMenu -Force
```

Если остались `__ЗАПОЛНИТЕ__`, проверка выведет список полей.

Типичные ошибки JSON:

- лишняя запятая после последнего элемента в объекте/массиве;
- незакрытая кавычка;
- одинарные кавычки вместо двойных;
- комментарии `//` — в JSON нельзя.

Проверка синтаксиса:

```powershell
Get-Content .\config\my-ha-cluster.json -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
Write-Host 'JSON OK'
```

---

## 6. Что получается после `-GenerateHa`

Каталог `output/18-ha-wizard/`:

- `01`…`08` — shell-скрипты и гайды
- `09-healthcheck.ps1`
- `nginx-site.conf`, `termidesk.conf.snippet`, `README-deploy-order.txt`

Дальше — пошаговое развёртывание **[18] → 1…9** (см. `НАСТРОЙКА-КЛАСТЕРА.html`).

---

## 7. Связь файлов

| Файл | Роль |
|------|------|
| `config/ha-cluster.template.json` | Шаблон (не править оригинал — копировать) |
| `config/my-ha-cluster.json` | Ваша заполненная копия (имя любое) |
| `config/termidesk-settings.json` | Рабочий конфиг панели после импорта |
| `config/cluster-config.json` | Синхронизируется автоматически |
| `config/termidesk-settings.example.json` | Старый example со демо-IP (для пункта [1], не для боя) |

---

## 8. Чек-лист заполнения

- [ ] Скопирован шаблон, оригинал не испорчен
- [ ] Нет строк `__ЗАПОЛНИТЕ`
- [ ] ≥ 2 диспетчера, один `isReference: true`
- [ ] ≥ 2 шлюза; при standard ≥ 2 CeleryMan
- [ ] ≥ 1 узел LB + VIP FQDN
- [ ] Пути TLS — Linux (`/etc/...`), не `C:\`
- [ ] `dhparamPath` = `/etc/nginx/dhparam.pem` (файл создадите на LB)
- [ ] Пароли БД, RabbitMQ, portal, gateway заданы
- [ ] `pgHbaNetwork` — ваш CIDR
- [ ] JSON парсится (`ConvertFrom-Json`)
- [ ] Запуск с `-SettingsFile` и `-GenerateHa` успешен

---

*Панель Termidesk VDI 7.0 — пункт [18] → [4] / [T], CLI `-SettingsFile`.*
