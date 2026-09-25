# Каталог требований ИБ-1…132 и слияние с детальными сценариями проверки

function Get-TermideskIbRequirementsCatalog {
    $root = Split-Path -Parent $PSScriptRoot
    $path = Join-Path $root 'output/19-ib-compliance/ib-requirements-full.tsv'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Не найден каталог требований: $path"
    }
    Get-Content -LiteralPath $path -Encoding UTF8 |
        Select-Object -Skip 1 |
        ForEach-Object {
            $p = $_ -split "`t", 3
            if ($p.Count -ge 3) {
                @{ Id = $p[0].Trim(); Cat = $p[1].Trim(); Req = $p[2].Trim() }
            }
        }
}

function Get-TermideskIbScenarioOverrides {
    param([object]$Settings)
    $portal = if ($Settings.portal.url) { $Settings.portal.url } else { 'https://portal.example.ru' }
    $o = @{}
    function Add-Override {
        param($Id, $Steps, $Shots = @('Подтверждение в протоколе'), $Script = '', $Type = 'manual', $Exp = 'Требование выполнено', [switch]$Pwd, [switch]$Cert, [switch]$Session)
        $o[$Id] = @{ Steps = $Steps; Shots = $Shots; Script = $Script; Type = $Type; Exp = $Exp; Pwd = [bool]$Pwd; Cert = [bool]$Cert; Session = [bool]$Session }
    }

    Add-Override 'ИБ-91' @('Сгенерируйте артефакты: меню [19]→2 или [A]','На эталонном диспетчере выполните скрипт с порогом 80%','Убедитесь, что при превышении порога выводится WARNING ИБ-91','При необходимости настройте мониторинг Zabbix на тот же порог') @('Мониторинг → триггер заполнения /var/log/termidesk','Вывод скрипта с WARNING при тестовом заполнении диска') 'scripts/ib-91-check-log-disk.sh' 'bash' 'Скрипт возвращает WARNING при ≥80% заполнения тома с журналами'
    Add-Override 'ИБ-92' @('Портал → Система → Системные настройки → Аудит','Включите «Сохранение в файл журнала»','Задайте «Количество архивных файлов (7-30)» — например 14','В termidesk.conf проверьте LOG_DEEP','Выполните скрипт проверки ротации') @('Портал: раздел Аудит — параметр архивных файлов','Каталог /var/log/termidesk/ — файлы audit.log.* после ротации') 'scripts/ib-92-check-log-rotation.sh' 'bash' 'LOG_DEEP задан; audit.log.* существуют; ротация настроена'
    Add-Override 'ИБ-93' @('Выполните скрипт проверки прав на диспетчере','Убедитесь: mode 0440 или строже, владелец termidesk:adm','Проверьте audit.log и каталог LOG_DIR') @('Вывод stat для /var/log/termidesk/audit.log','Права каталога /var/log/termidesk') 'scripts/ib-93-check-log-permissions.sh' 'bash' 'Скрипт завершается с кодом 0, права 0440/0400'
    Add-Override 'ИБ-94' @('На всех узлах: timedatectl set-ntp true','В мастере [18] задайте NTP-сервер','Выполните скрипт проверки синхронизации') @('timedatectl status — System clock synchronized: yes','Конфиг /etc/systemd/timesyncd.conf или chrony') 'scripts/ib-94-check-ntp.sh' 'bash' 'NTP active, часы синхронизированы'
    Add-Override 'ИБ-95' @('Портал → Аудит → «Отправка в Syslog» = Да','Укажите хост SIEM, порт, протокол TCP/TLS','Выполните configure-audit-syslog.sh на диспетчере','Проверьте поступление событий на SIEM') @('Портал: параметры Syslog в разделе Аудит','SIEM: входящее событие AUDIT от Termidesk') 'scripts/ib-95-configure-syslog.sh' 'bash' 'rsyslog пересылает audit; события видны в SIEM'
    Add-Override 'ИБ-96' @('Откройте документацию Termidesk «Типы событий аудита»','Сверьте атрибуты с таблицей ГОСТ Р 59548-2022','Выполните скрипт выборки типов событий из audit.log') @('Документация: типы событий аудита Termidesk','Пример записи audit.log с полями события') 'scripts/ib-96-check-audit-events.sh' 'bash' 'События содержат идентификатор, время, субъект, объект, результат'
    Add-Override 'ИБ-97' @('Убедитесь INTERNAL_AUDIT=True в termidesk.conf','Проверьте отдельный файл /var/log/termidesk/audit.log','Системные логи не смешиваются с audit') @('Файл audit.log отдельно от syslog/journal','Портал: INTERNAL_AUDIT включён') 'scripts/ib-97-check-audit-separation.sh' 'bash' 'audit.log существует; programname termidesk audit отделён'
    Add-Override 'ИБ-98' @('Откройте incident-response-ib98.md','Согласуйте с локальным SOC процедуры','Включите ссылку в эксплуатационную документацию стенда') @('Таблица инцидентов в incident-response-ib98.md') 'incident-response-ib98.md' 'doc' 'Документ согласован; процедуры утверждены'
    Add-Override 'ИБ-99' @('Получите рекомендации Kaspersky/Dr.Web для VDI','Добавьте исключения для /opt/termidesk, /var/log/termidesk','Проверьте работу termidesk-vdi при включённом AV') @('Политика AV: исключения путей Termidesk','Служба termidesk-vdi active при AV') 'scripts/ib-99-antivirus-paths.txt' 'doc' 'AV не блокирует компоненты; исключения применены'
    Add-Override 'ИБ-100' @('Загрузите отчёт MaxPatrol/Nexpose по узлам Termidesk','Устраните Critical/High или задокументируйте компенсации','Обновите пакеты Termidesk до актуальной версии 7.0') @('Отчёт СМЗИС без Critical/High по termidesk-* пакетам') 'scripts/ib-100-vulnerability-checklist.ps1' 'powershell' 'Нет открытых Critical/High по матрице стенда'
    Add-Override 'ИБ-101' @('Задайте HEALTH_CHECK_ACCESS_KEY в termidesk-settings.json','Выполните check-health-api.ps1 с Windows','Проверьте /api/health и /api/health/metrics') @('Ответ JSON /api/health/?key=...','Metrics API — статус компонентов') 'scripts/ib-101-check-health-api.ps1' 'powershell' 'Health OK, metrics доступны'
    Add-Override 'ИБ-102' @('Откройте network-ports-ib102.txt и firewall-ports.txt','Сверьте с матрицей firewall стенда','Добавьте в эксплуатационную документацию') @('Таблица портов в network-ports-ib102.txt') 'scripts/ib-102-network-ports.txt' 'doc' 'Порты задокументированы и согласованы с СИ'
    Add-Override 'ИБ-103' @('Смените пароль PostgreSQL — см. раздел «Замена паролей»','Смените пароль RabbitMQ','Смените пароль admin портала','Задайте HEALTH_CHECK_ACCESS_KEY','Выполните скрипт проверки defaults') @('termidesk.conf — нет пустых DBPASS/RABBITMQ_PASS','Портал: смена пароля admin') 'scripts/ib-103-check-defaults.sh' 'bash' 'Нет дефолтных/пустых паролей в конфиге' -Pwd
    Add-Override 'ИБ-104' @('Проверьте доступность репозитория Termidesk 7.0','Выполните apt list --upgradable | grep termidesk','Зафиксируйте версию в протоколе') @('apt policy termidesk-vdi — актуальная версия') 'scripts/ib-104-check-updates.sh' 'bash' 'Пакеты актуальны или план обновления утверждён'
    Add-Override 'ИБ-105' @('Для .deb-установки: N/A — зафиксируйте в протоколе','При контейнерах: используйте корпоративный registry') @('Протокол: способ поставки .deb')
    Add-Override 'ИБ-106' @('Пройдите НАСТРОЙКА-КЛАСТЕРА.html','Примените политики безопасности портала','Выполните чек-лист ib-106') @('Production-чек-лист HA выполнен') 'scripts/ib-106-security-checklist.sh' 'bash' 'Чек-лист ИБ-7 выполнен'
    Add-Override 'ИБ-107' @('Сформируйте матрицу соответствия КТ-233','Приложите к протоколу апробирования') @('Матрица соответствия КТ-233') 'scripts/ib-107-gpn-matrix.md' 'doc' 'Матрица заполнена и согласована'
    Add-Override 'ИБ-108' @('Termidesk не содержит встроенного языка — N/A','Зафиксируйте в протоколе') @('Протокол: N/A') '' 'manual' 'N/A задокументировано'
    Add-Override 'ИБ-109' @('Проверьте sources.list.d/termidesk-vdi.list','Убедитесь, что repo — корпоративный mirror Termidesk') @('/etc/apt/sources.list.d/termidesk-vdi.list') 'scripts/ib-109-check-repo.sh' 'bash' 'Репозиторий из утверждённого списка'
    Add-Override 'ИБ-110' @('Создайте baseline: sudo bash check-integrity.sh /var/lib/termidesk/baseline.sha256 create','Периодически проверяйте без create','При изменении — расследование') @('Вывод OK для termidesk.conf и termidesk-config') 'scripts/ib-110-check-integrity.sh' 'bash' 'Контрольные суммы совпадают'
    Add-Override 'ИБ-111' @('Опишите процедуру ib-110 в эксплуатационной доку','Укажите ЗПС termidesk-digsig-keys') @('Процедура целостности в документации') 'scripts/ib-111-integrity-procedure.md' 'doc' 'Процедура описана'
    Add-Override 'ИБ-112' @('Разверните HA по [18]: ≥2 диспетчера, шлюза, LB','Выполните healthcheck и failover-тест') @('Портал: статус компонентов — все green','Отключение одного диспетчера — VIP доступен') 'scripts/ib-112-ha-check.ps1' 'powershell' 'Кластер доступен при отказе одного узла'
    Add-Override 'ИБ-113' @('Настройте [16] backup-db.sh и backup-config.sh','Выполните тестовое восстановление на стенде','Задокументируйте расписание и retention') @('Файл backup termidesk_*.tar','Успешный restore на тестовом узле') '../16-backup/backup-db.sh' 'bash' 'Backup и restore проверены'
    Add-Override 'ИБ-114' @('Задайте HTTP_PROXY/HTTPS_PROXY на узлах обновления','Ограничьте исходящий трафик firewall','Проверьте apt update через прокси') @('/etc/environment — proxy vars','Firewall: deny default outbound') 'scripts/ib-114-proxy-example.sh' 'bash' 'Обновления только через прокси'
    Add-Override 'ИБ-115' @('Front: nginx VIP :443','Back: диспетчеры, PostgreSQL, RabbitMQ в защищённом сегменте','Клиенты не имеют прямого доступа к 5432/5672') @('Схема сети: VIP → LB → dispatchers','Firewall: 5432 только с подсети приложений') 'scripts/ib-115-segmentation-checklist.md' 'doc' 'Сегментация реализована'
    Add-Override 'ИБ-116' @('Убедитесь: on-prem Termidesk не требует постоянного Internet','Отключите исходящий Internet — портал работает') @('Портал доступен без Internet') 'scripts/ib-116-offline-check.sh' 'bash' 'Работа без Internet подтверждена'
    Add-Override 'ИБ-117' @('PostgreSQL: scram-sha-256 в pg_hba.conf','termidesk.conf: DBPASS через scramble','Не храните plaintext в git') @('pg_hba.conf — scram-sha-256','scramble --value test (демо преобразования)') 'scripts/ib-117-check-password-storage.sh' 'bash' 'scram-sha-256; scramble в conf' -Pwd
    Add-Override 'ИБ-118' @('Используйте scramble --type AES256_V2 для conf','RabbitMQ: password_hash в definitions.json') @('scramble / definitions.json') 'scripts/ib-118-check-hash-algo.sh' 'bash' 'AES256_V2 / современные алгоритмы'
    Add-Override 'ИБ-119' @('nginx ssl_protocols TLSv1.2 TLSv1.3','Проверьте openssl s_client -connect VIP:443') @('nginx ssl-params — TLSv1.2 TLSv1.3','openssl s_client — Protocol TLSv1.3') 'scripts/ib-119-check-tls.sh' 'bash' 'Только TLS 1.2+'
    Add-Override 'ИБ-120' @('Настройте mTLS: [10] → generate-user-certificate.sh','Домен X.509 в портале','Проверьте вход с клиентским сертификатом') @('termidesk-config — MTLS_MODE','Успешный login по сертификату') '../10-ssl/generate-user-certificate.sh' 'bash' 'mTLS и домен X.509 работают' -Cert
    Add-Override 'ИБ-121' @('TLS на VIP FQDN','Корпоративный сертификат, не self-signed') @('HTTPS TLS 1.2+ на пользовательском канале') 'scripts/ib-121-125-tls-connectivity.sh' 'bash' 'HTTPS TLS 1.2+ на пользовательском канале'
    Add-Override 'ИБ-122' @('TLS на границе DMZ','Разделение front/back — ИБ-115') @('TLS в DMZ подтверждён') 'scripts/ib-121-125-tls-connectivity.sh' 'bash' 'TLS в DMZ подтверждён'
    Add-Override 'ИБ-123' @('HTTPS диспетчеры; опционально PostgreSQL SSL (DBCERT)','AMQPS при необходимости') @('Межкомпонентное HTTPS/TLS') 'scripts/ib-121-125-tls-connectivity.sh' 'bash' 'Межкомпонентное HTTPS/TLS'
    Add-Override 'ИБ-124' @('LDAPS к AD; HTTPS к oVirt; syslog TLS к SIEM') @('Внешние интеграции по TLS') 'scripts/ib-121-125-tls-connectivity.sh' 'bash' 'Внешние интеграции по TLS'
    Add-Override 'ИБ-125' @('Установите корпоративный CA на LB и клиентов','mTLS с корпоративными сертификатами') @('PKI интегрирована') 'scripts/ib-125-pki-checklist.md' 'doc' 'PKI интегрирована' -Cert
    Add-Override 'ИБ-126' @('Сценарий STAL + smart-card / Рutoken','Kerberos keytab по документации STAL') @('Smart-card сценарий')
    Add-Override 'ИБ-127' @('Минимизируйте ПДн в audit.log','Политики домена — маскирование при экспорте') @('ПДн обезличены')
    Add-Override 'ИБ-128' @('При требовании — CryptoPro CSP + совместимая сборка Termidesk') @('СКЗИ работает')
    Add-Override 'ИБ-129' @('Приложите заключение ФСБ на используемое СКЗИ') @('Документы ФСБ приложены') '' 'doc' 'Документы приложены'
    Add-Override 'ИБ-130' @('Используйте ib-110-check-integrity.sh','Сверьте с процедурой ЗПС') @('Целостность подтверждена') 'scripts/ib-110-check-integrity.sh' 'bash' 'Целостность подтверждена'
    Add-Override 'ИБ-131' @('Приложите отчёт DAST/пентест без критичных НДВ') @('Отчёт DAST приложен') '' 'doc' 'Отчёт приложен'
    Add-Override 'ИБ-132' @('При наличии исходников — отчёт SAST вендора') @('SAST отчёт приложен') '' 'doc' 'SAST отчёт приложен'

    # Ключевые требования ИБ-1…44 с привязкой к разделам HTML
    Add-Override 'ИБ-14' @('См. раздел «Сертификаты» — выпуск cert и домен X.509','Проверьте вход с клиентским сертификатом') @('Успешный login по сертификату') '' 'manual' 'Аутентификация по сертификату работает' -Cert
    Add-Override 'ИБ-22' @('См. раздел «Замена паролей»','Замените пароли всех встроенных учётных записей') @('Нет дефолтных паролей') 'scripts/ib-103-check-defaults.sh' 'bash' 'Пароли по умолчанию заменены' -Pwd
    Add-Override 'ИБ-43' @('См. раздел «Сессии/API» — таймаут неактивности','После таймаута без действий требуется повторный login') @('Повторная аутентификация после блокировки') '' 'manual' 'Сессия блокируется по неактивности' -Session
    Add-Override 'ИБ-44' @('Токен POST /api/auth/v7.0/login (X-Auth-Token): портал → Системные параметры → Безопасность → «Длительность сессии администратора, с»','Если есть Агрегатор: AGGREGATOR_ACCESS_TOKEN_TTL_SECONDS на узле Агрегатора через termidesk-config или termidesk.conf','После изменения — перезапуск служб; проверьте 401 после истечения TTL','Отзыв: /api/auth/v7.0/legacy/logout') @('Портал: «Длительность сессии администратора, с»','termidesk.conf на Агрегаторе: AGGREGATOR_ACCESS_TOKEN_TTL_SECONDS','401 на API после истечения срока') '' 'manual' 'Срок действия токена определён и согласован' -Session

    return $o
}

function New-TermideskIbDefaultScenario {
    param([object]$Item, [object]$Settings)
    $portal = if ($Settings.portal.url) { $Settings.portal.url } else { 'https://portal.example.ru' }
    $num = [int]($Item.Id -replace '^ИБ-','')
    $steps = @(
        'Изучите официальную документацию Termidesk 7.0 по теме требования'
        'Выполните проверку на стенде согласно формулировке требования'
        'Зафиксируйте результат и приложите скриншоты к протоколу апробирования'
    )
    $shots = @('Подтверждение выполнения — скриншот или документ')
    $script = ''
    $type = 'manual'
    $exp = 'Требование выполнено и задокументировано в протоколе'
    $pwd = $false; $cert = $false; $session = $false

    if ($num -ge 1 -and $num -le 7) {
        if ($num -in 3, 4) {
            $steps = @('Откройте https://reestr.digital.gov.ru/reestr/ и найдите Termidesk','Сохраните скриншот записи реестра','Приложите к протоколу апробирования')
        } elseif ($num -in 5, 6) {
            $steps = @('Запросите у вендора копию сертификата ФСТЭК','Проверьте срок действия и область сертификации','Приложите к протоколу')
        } elseif ($num -eq 7) {
            $steps = @('Откройте документацию Termidesk: security / hardening guide','Сверьте с НАСТРОЙКА-КЛАСТЕРА.html и чек-листом ИБ-106','Примените рекомендации на стенде')
        } else {
            $steps = @('Запросите у вендора актуальную информацию по требованию','Сохраните выписку из документации или портала поддержки','Приложите к протоколу')
        }
    }
    elseif ($num -ge 8 -and $num -le 28) {
        if ($num -eq 11) { $steps = @('Создайте локального пользователя в портале','Проверьте вход по паролю на $portal') }
        elseif ($num -in 12, 13) { $steps = @('Выполните login API /api/auth/v7.0/login','Проверьте read/write API с Bearer-токеном','Анонимный доступ к API запрещён') }
        elseif ($num -in 15, 16, 17) { $steps = @('Портал → политики паролей / системные настройки','Проверьте маскирование пароля при вводе и политику сложности') }
        elseif ($num -ge 18 -and $num -le 21) { $steps = @('Портал → политики паролей: блокировка, история, срок, смена при первом входе','Проверьте на тестовой учётной записи') }
        elseif ($num -eq 23) { $steps = @('Портал → Пользователи — блокировка встроенных УЗ','Проверьте невозможность входа заблокированной УЗ') }
        elseif ($num -ge 24 -and $num -le 28) { $steps = @('Портал → Домены: LDAP/LDAPS или OIDC/SAML','Проверьте SSO/Kerberos/MFA по матрице размещения стенда') }
        else { $steps = @('Портал → Пользователи/Домены — проверьте уникальность идентификаторов','Компоненты: termidesk.conf — уникальные ID сервисов') }
    }
    elseif ($num -ge 29 -and $num -le 42) {
        $steps = @('Проверьте RBAC в UI, API и CLI (termidesk-config / sudo)','Портал → Роли и группы; анонимный доступ к UI/API запрещён','Процессы termidesk работают от непривилегированной УЗ')
    }
    elseif ($num -eq 45) {
        $steps = @('Портал → Система → Аудит — механизмы регистрации включены','Проверьте /var/log/termidesk/audit.log')
    }
    elseif ($num -eq 46) {
        $steps = @('Документация Termidesk: типы событий аудита и изменения конфигурации','Сверьте с фактическими записями audit.log')
    }
    elseif ($num -eq 47) {
        $steps = @('Портал → просмотр/экспорт журнала аудита','Или централизованный SIEM')
    }
    elseif ($num -ge 48 -and $num -le 72) {
        $event = if ($Item.Req -match '«([^»]+)»') { $Matches[1] } else { 'событие из требования' }
        $steps = @(
            "Выполните действие, генерирующее событие «$event»"
            'Проверьте запись в /var/log/termidesk/audit.log'
            'При интеграции с SIEM — проверьте поступление события'
        )
    }
    elseif ($num -ge 73 -and $num -le 87) {
        $field = if ($Item.Req -match '«([^»]+)»') { $Matches[1] } else { 'атрибут' }
        $steps = @(
            'Выполните действие, создающее запись audit.log'
            "Убедитесь, что присутствует поле «$field»"
            'Сверьте атрибутный состав с ГОСТ Р 59548-2022 (скрипт ИБ-96)'
        )
        $script = 'scripts/ib-96-check-audit-events.sh'
        $type = 'bash'
    }
    elseif ($num -eq 88) {
        $steps = @('Проверьте audit.log и syslog — нет plaintext паролей','grep -i password /var/log/termidesk/audit.log — секретов быть не должно')
    }
    elseif ($num -eq 89) {
        $steps = @('Документация Termidesk: типы событий с уникальными ID','Сверьте идентификаторы в audit.log')
    }
    elseif ($num -eq 90) {
        $steps = @('Портал → Аудит → срок хранения / ротация','Проверьте LOG_DEEP и архивные файлы audit.log.*')
    }

    return @{
        Id = $Item.Id; Cat = $Item.Cat; Req = $Item.Req
        Steps = $steps; Shots = $shots; Script = $script; Type = $type; Exp = $exp
        Pwd = $pwd; Cert = $cert; Session = $session
    }
}

function Get-TermideskIbScenarios {
    param([object]$Settings)
    if (-not $Settings) { $Settings = @{ portal = @{ url = 'https://portal.example.ru' } } }
    $catalog = @(Get-TermideskIbRequirementsCatalog)
    $overrides = Get-TermideskIbScenarioOverrides -Settings $Settings
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($item in $catalog) {
        if ($overrides.ContainsKey($item.Id)) {
            $o = $overrides[$item.Id]
            [void]$result.Add(@{
                Id = $item.Id; Cat = $item.Cat; Req = $item.Req
                Steps = $o.Steps; Shots = $o.Shots; Script = $o.Script; Type = $o.Type; Exp = $o.Exp
                Pwd = $o.Pwd; Cert = $o.Cert; Session = $o.Session
            })
        } else {
            [void]$result.Add((New-TermideskIbDefaultScenario -Item $item -Settings $Settings))
        }
    }
    return $result
}

function Get-TermideskSkRequirementsCatalog {
    $root = Split-Path -Parent $PSScriptRoot
    $path = Join-Path $root 'output/19-ib-compliance/sk-requirements-full.tsv'
    if (-not (Test-Path -LiteralPath $path)) { throw "Не найден каталог СК: $path" }
    Get-Content -LiteralPath $path -Encoding UTF8 |
        Select-Object -Skip 1 |
        ForEach-Object {
            $p = $_ -split "`t", 3
            if ($p.Count -ge 3) {
                @{ Id = $p[0].Trim(); Cat = $p[1].Trim(); Req = $p[2].Trim() }
            }
        }
}

function Get-TermideskSkScenarios {
    param([object]$Settings)
    $portal = if ($Settings.portal.url) { $Settings.portal.url } else { 'https://portal.example.ru' }
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($item in @(Get-TermideskSkRequirementsCatalog)) {
        $num = [int]($item.Id -replace '^СК-','')
        $steps = if ($num -ge 14 -and $num -le 23) {
            switch ($num) {
                14 { @('wine ./setup.exe или аналог по матрице вендора') }
                15 { @('Запустите Windows-клиент через Wine') }
                16 { @('Проверьте отображение GUI в Wine') }
                17 { @('Кнопки и меню в Wine-клиенте') }
                18 { @('Интерактивные элементы в Wine') }
                19 { @('Подключение к стенду через Wine-клиент') }
                20 { @('Copy/paste в Wine-сессии') }
                21 { @('Обмен с Р7-Офис через Wine') }
                22 { @('Файловые операции в Wine') }
                23 { @('Штатное закрытие Wine-клиента') }
            }
        } else {
            switch ($num) {
                1 { @("На Astra Linux SE «Воронеж» откройте $portal в Яндекс Браузере") }
                2 { @('Визуально осмотрите портал после входа') }
                3 { @('Логин admin','Навигация по разделам','Выдача тестовой ВРМ') }
                4 { @('Установите .deb клиента Termidesk из корпоративного репозитория') }
                5 { @('Запустите termidesk-connect / TERA client') }
                6 { @('Откройте главное окно клиента') }
                7 { @('Проверьте кнопки, списки, меню') }
                8 { @('Откройте диалоги и формы в клиенте') }
                9 { @('Подключитесь к фонду/шлюзу со стенда') }
                10 { @('Copy/paste между локальной ОС и сессией') }
                11 { @('Откройте документ Р7-Офис из сессии') }
                12 { @('Доступ к FS из клиента (если включено политикой)') }
                13 { @('Закройте клиент через меню «Выход»') }
                24 { @('URI/handler из клиента на локальное ПО') }
                25 { @('Проверьте процесс вызванного приложения в ОС (ps/top)') }
                default { @('Выполните проверку согласно формулировке требования','Зафиксируйте результат в sk-report-template.csv') }
            }
        }
        $exp = switch ($num) {
            1 { 'Страница загружается' }
            2 { 'Веб-интерфейс отображается корректно' }
            3 { 'Веб-интерфейс работает корректно' }
            13 { 'Штатный выход без зависания' }
            23 { 'Штатный выход Wine-клиента' }
            25 { 'Прикладное ПО запущено' }
            default { 'Критерий выполнен' }
        }
        [void]$result.Add(@{
            Id = $item.Id; Cat = $item.Cat; Req = $item.Req
            Steps = $steps; Shots = @('Скриншот подтверждения проверки'); Exp = $exp
        })
    }
    return $result
}

function Get-TermideskParameterGuide {
    param([object]$Settings)
    $portal = if ($Settings -and $Settings.portal.url) { $Settings.portal.url } else { 'https://portal.example.ru' }
    @(
        @{ Slug='dbpass'; Group='Пароли и секреты'; Name='DBPASS'; Ib='ИБ-103, ИБ-117, ИБ-118'
            Where=@('Linux: /etc/opt/termidesk-vdi/termidesk.conf → DBPASS','CLI: sudo /opt/termidesk/sbin/termidesk-config → «Настройка подключения к СУБД»','Windows-панель: config/termidesk-settings.json → database.password','OpenBao: секрет SECRETS_OPENBAO_DB_PATH')
            How=@('Смените пароль в PostgreSQL: sudo bash output/03-database/02-change-password.sh ''NovyjParol''','На каждом диспетчере и CeleryMan задайте DBPASS через termidesk-config (scramble)','Обновите database.password в JSON при использовании [18]','Перезапуск: termidesk-config → «Перезапуск служб»') }
        @{ Slug='rabbitmq-pass'; Group='Пароли и секреты'; Name='RABBITMQ_PASS'; Ib='ИБ-103, ИБ-118'
            Where=@('termidesk.conf → RABBITMQ_PASS','termidesk-config → «Настройка подключения к RabbitMQ»','JSON: rabbitmq.password')
            How=@('Смените пароль брокера: output/04-rabbitmq/02-change-password.sh','Обновите RABBITMQ_PASS на всех диспетчерах','Синхронизируйте coordinatorPass на шлюзах','Перезапуск termidesk-vdi') }
        @{ Slug='coordinator-pass'; Group='Пароли и секреты'; Name='coordinatorPass'; Ib='ИБ-103'
            Where=@('termidesk.conf на шлюзе','JSON: gateway.coordinatorPass','termidesk-config на шлюзе')
            How=@('Тот же пароль, что у RABBITMQ_PASS','Проверьте coordinatorUrl','Перезапуск служб шлюза') }
        @{ Slug='health-key'; Group='Пароли и секреты'; Name='HEALTH_CHECK_ACCESS_KEY'; Ib='ИБ-101, ИБ-103'
            Where=@('termidesk.conf → HEALTH_CHECK_ACCESS_KEY','termidesk-config → Health Check','JSON: monitoring.healthCheckAccessKey')
            How=@('Сгенерируйте случайную строку ≥32 символов','Задайте через termidesk-config','Проверьте GET /api/health/?key=...') }
        @{ Slug='metrics-key'; Group='Пароли и секреты'; Name='METRICS_ACCESS_KEY'; Ib='ИБ-101'
            Where=@('termidesk.conf → METRICS_ACCESS_KEY','JSON: monitoring.metricsAccessKey')
            How=@('Задайте ключ как HEALTH_CHECK_ACCESS_KEY','Проверьте /api/health/metrics') }
        @{ Slug='admin-password'; Group='Пароли и секреты'; Name='Пароль admin портала'; Ib='ИБ-103, ИБ-11…22'
            Where=@("Портал $portal → профиль admin → смена пароля",'Портал → Пользователи → admin')
            How=@('Смените пароль (не example из шаблона)','Проверьте политику паролей ИБ-16…21') }

        @{ Slug='dbhost'; Group='PostgreSQL / СУБД'; Name='DBHOST, DBHOST2, DBHOST3'; Ib='ИБ-112'
            Where=@('termidesk.conf → DBHOST*','termidesk-config → СУБД','JSON: database.host(s)','output/03-database/cluster-notes.txt')
            How=@('VIP Patroni или адреса узлов','DB_CLUSTER_MODE=cluster для HA','Перезапуск termidesk-vdi') }
        @{ Slug='db-cluster'; Group='PostgreSQL / СУБД'; Name='DB_CLUSTER_MODE'; Ib='ИБ-112'
            Where=@('termidesk.conf','termidesk-config → тип СУБД','JSON: database.clusterMode')
            How=@('standalone / cluster по архитектуре','Согласуйте с 01-postgresql-setup.sh') }
        @{ Slug='pg-hba'; Group='PostgreSQL / СУБД'; Name='pg_hba.conf (scram-sha-256)'; Ib='ИБ-117'
            Where=@('/etc/postgresql/*/main/pg_hba.conf','output/03-database/pg_hba.conf.snippet')
            How=@('host ... scram-sha-256','CIDR только подсеть приложений','reload postgresql','ib-117-check-password-storage.sh') }
        @{ Slug='dbcert'; Group='PostgreSQL / СУБД'; Name='DBCERT'; Ib='ИБ-123'
            Where=@('termidesk.conf → DBCERT','JSON: database.sslCertPath')
            How=@('Путь к CA/cert для TLS до PostgreSQL','Перезапуск termidesk-vdi') }

        @{ Slug='rmq-host'; Group='RabbitMQ'; Name='RABBITMQ_HOST, PORT, USER'; Ib='ИБ-102, ИБ-115'
            Where=@('termidesk.conf','termidesk-config → RabbitMQ','JSON: rabbitmq.*')
            How=@('Адрес кластера/VIP','Порт 5672 (5671 TLS)','Firewall только из app-сегмента') }
        @{ Slug='tmq'; Group='TermideskMQ'; Name='TMQ_*'; Ib='ИБ-102'
            Where=@('termidesk.conf (NODE_ROLES=TERMQ)','output/04-rabbitmq/termidesk.conf.tmq')
            How=@('termidesk-config → TermideskMQ','Перезапуск после изменения') }

        @{ Slug='ldap-domain'; Group='Портал — идентификация'; Name='Домены LDAP/OIDC/SAML'; Ib='ИБ-24…28, ИБ-35'
            Where=@('Портал → Аутентификация → Домены','output/12-domains/')
            How=@('Создайте домен LDAPS/OIDC/SAML','Привяжите к группам','Проверьте SSO/MFA') }
        @{ Slug='x509-domain'; Group='Портал — идентификация'; Name='Домен X.509'; Ib='ИБ-14, ИБ-120'
            Where=@('Портал → Домены → X.509','Раздел «Сертификаты» в этом HTML')
            How=@('mTLS на диспетчере','Домен X.509 + сопоставление DN/CN','Вход с user.p12') }
        @{ Slug='password-policy'; Group='Портал — идентификация'; Name='Парольная политика'; Ib='ИБ-16…21'
            Where=@('Портал → Система → Системные настройки → безопасность')
            How=@('Сложность, срок, история, блокировка, первый вход') }
        @{ Slug='rbac'; Group='Портал — доступ'; Name='Роли и группы'; Ib='ИБ-29…42'
            Where=@('Портал → Пользователи → Группы/Роли','API + termidesk-config CLI')
            How=@('Минимальные права (ИБ-34)','Наследование LDAP (ИБ-35)','Без анонимного UI/API') }

        @{ Slug='session-timeout'; Group='Сессии и API'; Name='Таймаут неактивности (ИБ-43)'; Ib='ИБ-43'
            Where=@("Портал $portal → Настройки → Системные параметры → Безопасность",'Политики пользовательского портала и клиентов Connect')
            How=@('Задайте таймаут неактивности (название поля зависит от сборки 7.0)','Проверка: после простоя без действий API/UI требуют новый login','Не путать с «Длительность сессии администратора, с» — это абсолютный срок, а не простой') }
        @{ Slug='api-x-auth-token'; Group='Сессии и API'; Name='X-Auth-Token (/api/auth/v7.0/login)'; Ib='ИБ-44, ИБ-12, ИБ-13'
            Where=@("Портал администратора $portal → Настройки → Системные параметры → Безопасность → «Длительность сессии администратора, с»",'POST /api/auth/v7.0/login → поле token, дальше заголовок X-Auth-Token','Это основной API-токен диспетчера; не AGGREGATOR_ACCESS_TOKEN_TTL_SECONDS')
            How=@('Откройте портал администратора → Настройки → Системные параметры → Безопасность','Измените «Длительность сессии администратора, с» (значение в секундах, напр. 1800)','Сохраните; выполните login API и проверьте, когда тот же X-Auth-Token начнёт отдавать 401','Принудительный отзыв: GET или POST /api/auth/v7.0/legacy/logout с заголовком X-Auth-Token') }
        @{ Slug='api-token-ttl'; Group='Сессии и API'; Name='AGGREGATOR_ACCESS_TOKEN_TTL_SECONDS'; Ib='ИБ-44 (только если есть Агрегатор)'
            Where=@('Узел с Агрегатором: /etc/opt/termidesk-vdi/termidesk.conf → AGGREGATOR_ACCESS_TOKEN_TTL_SECONDS','termidesk-config → «Настройки Агрегатора» → «Время жизни токена Агрегатора, секунд»','Портал Агрегатора → Системные настройки → «Время жизни access token, с»','По умолчанию 600 с; JWT для связи Агрегатор↔диспетчер (/api/auth/v7.0/jwtauth), не login диспетчера')
            How=@('SSH на узел Агрегатора (TERMIDESK_FARM_MODE=aggregator)','Способ 1: sudo /opt/termidesk/sbin/termidesk-config → «Настройки Агрегатора» → «Время жизни токена Агрегатора, секунд» → новое значение (напр. 300)','Способ 2: sudo nano /etc/opt/termidesk-vdi/termidesk.conf → AGGREGATOR_ACCESS_TOKEN_TTL_SECONDS=''300''','Обязательно: termidesk-config → «Перезапуск служб» (или systemctl restart termidesk-vdi)','Проверка: grep AGGREGATOR_ACCESS_TOKEN_TTL /etc/opt/termidesk-vdi/termidesk.conf') }

        @{ Slug='internal-audit'; Group='Аудит'; Name='INTERNAL_AUDIT'; Ib='ИБ-45…97'
            Where=@('termidesk.conf','termidesk-config → Fluentd')
            How=@('INTERNAL_AUDIT=True','/var/log/termidesk/audit.log отдельно от syslog') }
        @{ Slug='log-deep'; Group='Аудит'; Name='LOG_DEEP, LOG_DIR'; Ib='ИБ-90…92'
            Where=@('termidesk.conf','Портал → Аудит → архивные файлы (7-30)')
            How=@('LOG_DEEP + ротация','Включить сохранение в файл','ib-92-check-log-rotation.sh') }
        @{ Slug='syslog'; Group='Аудит'; Name='Syslog → SIEM'; Ib='ИБ-95'
            Where=@('Портал → Аудит → Syslog','configure-audit-syslog.sh')
            How=@('Хост/порт SIEM','Скрипт на диспетчере','Событие на SIEM') }

        @{ Slug='mtls'; Group='TLS / mTLS'; Name='MTLS_MODE, MTLS_*'; Ib='ИБ-119…125'
            Where=@('termidesk.conf','termidesk-config → Сертификаты','/etc/opt/termidesk-vdi/mtls/','apache-mtls-snippet.conf')
            How=@('generate-user-certificate.sh','MTLS_MODE=on','Apache X-TDSK-SSL-CLIENT-*','Перезапуск') }
        @{ Slug='nginx-ssl'; Group='TLS / mTLS'; Name='TLS на VIP (nginx)'; Ib='ИБ-119, ИБ-121'
            Where=@('nginx ssl_* на LB','JSON cluster.tls','output/10-ssl/, output/09-nginx/')
            How=@('TLSv1.2+','Корпоративный cert','ib-119-check-tls.sh') }

        @{ Slug='farm-mode'; Group='Кластер и узлы'; Name='TERMIDESK_FARM_MODE, NODE_ROLES'; Ib='ИБ-112, ИБ-10'
            Where=@('termidesk.conf','termidesk-config → режим и роли','JSON [18]')
            How=@('FARM_MODE standalone/cluster','NODE_ROLES ADMIN,USER,CELERYMAN,TERMQ') }
        @{ Slug='secrets-storage'; Group='Кластер и узлы'; Name='config / hvac / openbao'; Ib='ИБ-103'
            Where=@('termidesk-config → хранение паролей','JSON openbao.*','output/05-openbao/')
            How=@('Выбор config или OpenBao','migrate-to-openbao.sh при миграции') }
        @{ Slug='gateway'; Group='Шлюз'; Name='coordinatorUrl, websockify'; Ib='ИБ-102, ИБ-115'
            Where=@('termidesk.conf шлюза','JSON gateway.*','[18] шлюзы')
            How=@('coordinatorUrl на диспетчер','Порты LB↔шлюз','VIP:443 для клиентов') }
        @{ Slug='json-template'; Group='JSON (Windows)'; Name='termidesk-settings.json'; Ib='ИБ-107, все'
            Where=@('config/termidesk-settings.json','ГАЙД-ШАБЛОН-JSON.html','Мастер [18]')
            How=@('Разделы 4.1–4.13 гайда','[A] перегенерация артефактов','Без паролей в git') }
    )
}

function New-TermideskHtmlParameterGuidePanel {
    param([object]$Settings)
    $params = @(Get-TermideskParameterGuide -Settings $Settings)
    $groups = $params | ForEach-Object { $_.Group } | Select-Object -Unique
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine(@"
<section id="tab-params" class="panel" data-title="Справочник параметров">
  <div class="panel-head"><h2>Справочник параметров — где найти и как изменить</h2><p class="lead">Для каждого параметра указаны все типичные места (портал, termidesk.conf, JSON, скрипты) и порядок изменения. Ищите по имени через строку поиска вверху.</p></div>
  <div class="param-toc">
"@)
    foreach ($g in $groups) {
        $gid = ($g -replace '[^a-zA-Zа-яА-Я0-9]','-').ToLower()
        [void]$sb.AppendLine("    <a href=""#param-grp-$gid"" class=""param-jump"">$g</a>")
    }
    [void]$sb.AppendLine('  </div>')
    $currentGroup = ''
    foreach ($p in $params) {
        if ($p.Group -ne $currentGroup) {
            $currentGroup = $p.Group
            $gid = ($currentGroup -replace '[^a-zA-Zа-яА-Я0-9]','-').ToLower()
            [void]$sb.AppendLine("<h3 id=""param-grp-$gid"" class=""param-group-title"">$currentGroup</h3>")
        }
        $nameEnc = ConvertTo-TermideskHtmlEncode $p.Name
        $ibEnc = ConvertTo-TermideskHtmlEncode $p.Ib
        $whereHtml = ($p.Where | ForEach-Object { "<li>$(ConvertTo-TermideskHtmlEncode $_)</li>" }) -join ''
        $howHtml = ($p.How | ForEach-Object { "<li>$(ConvertTo-TermideskHtmlEncode $_)</li>" }) -join ''
        $searchText = ConvertTo-TermideskHtmlEncode "$($p.Name) $($p.Ib) $currentGroup $($p.Slug)"
        [void]$sb.AppendLine(@"
  <div class="param-card" id="param-$($p.Slug)" data-search="$searchText">
    <div class="param-head"><code>$nameEnc</code><span class="tag tag-muted">$ibEnc</span></div>
    <h4>Где найти</h4>
    <ul class="param-where">$whereHtml</ul>
    <h4>Как изменить</h4>
    <ol class="steps param-how">$howHtml</ol>
  </div>
"@)
    }
    [void]$sb.AppendLine('  <label class="done-check"><input type="checkbox" data-store="tab-params"> Справочник параметров изучен</label>')
    [void]$sb.AppendLine('</section>')
    return $sb.ToString()
}
