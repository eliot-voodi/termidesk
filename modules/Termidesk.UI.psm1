# UI helpers for Termidesk interactive menu

function Show-TermideskBanner {
    Clear-Host
    Write-Host @"

  ╔══════════════════════════════════════════════════════════════════╗
  ║           Termidesk VDI 7.0 — Панель администрирования          ║
  ║         Полная настройка компонентов и отказоустойчивого HA      ║
  ╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
}

function Show-TermideskMainMenu {
    Show-TermideskBanner
    Write-Host '  Главное меню' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1]  Отказоустойчивый кластер (полная настройка HA)' -ForegroundColor Green
    Write-Host '  [18] Пошаговая настройка HA-кластера (без захардкоженных параметров)' -ForegroundColor Green
    Write-Host '  ─── Установка и инфраструктура ───' -ForegroundColor DarkGray
    Write-Host '  [2]  Подготовка среды функционирования'
    Write-Host '  [3]  Настройка СУБД PostgreSQL'
    Write-Host '  [4]  Настройка RabbitMQ / TermideskMQ'
    Write-Host '  [5]  Настройка OpenBao (хранилище секретов)'
    Write-Host '  ─── Компоненты Termidesk ───' -ForegroundColor DarkGray
    Write-Host '  [6]  Установка Универсального диспетчера'
    Write-Host '  [7]  Установка Менеджера рабочих мест'
    Write-Host '  [8]  Настройка Termidesk Connect (Шлюз)'
    Write-Host '  [9]  Настройка балансировщика nginx'
    Write-Host '  [10] Настройка SSL/TLS и сертификатов'
    Write-Host '  [11] Утилита termidesk-config'
    Write-Host '  ─── Портал и VDI ───' -ForegroundColor DarkGray
    Write-Host '  [12] Настройка доменов и аутентификации'
    Write-Host '  [13] Поставщики ресурсов и фонды VDI'
    Write-Host '  [14] Настройка Агрегатора'
    Write-Host '  ─── Эксплуатация ───' -ForegroundColor DarkGray
    Write-Host '  [15] Мониторинг и Health Check'
    Write-Host '  [16] Резервное копирование и восстановление'
    Write-Host '  [17] Журналирование, аудит и syslog'
    Write-Host '  ─── Прочее ───' -ForegroundColor DarkGray
    Write-Host '  [C]  Конфигурация (termidesk-settings.json)'
    Write-Host '  [A]  Сгенерировать ВСЕ скрипты и конфиги'
    Write-Host '  [O]  Открыть каталог output/'
    Write-Host '  [D]  Ссылки на документацию Termidesk 7.0'
    Write-Host '  [H]  Инструкции: панель / кластер / JSON-шаблон (HTML)'
    Write-Host '  [0]  Выход'
    Write-Host ''
}

function Show-TermideskInstruction {
    $root = Split-Path -Parent $PSScriptRoot
    $htmlPath = Join-Path $root 'ИНСТРУКЦИЯ.html'
    $mdPath = Join-Path $root 'ИНСТРУКЦИЯ.md'
    $clusterHtml = Join-Path $root 'НАСТРОЙКА-КЛАСТЕРА.html'
    $jsonGuide = Join-Path $root 'ГАЙД-ШАБЛОН-JSON.html'
    Show-TermideskBanner
    Write-Host '  Документация панели Termidesk 7.0' -ForegroundColor Yellow
    Write-Host ''
    $hasHtml = Test-Path -LiteralPath $htmlPath
    $hasMd = Test-Path -LiteralPath $mdPath
    $hasCluster = Test-Path -LiteralPath $clusterHtml
    $hasJson = Test-Path -LiteralPath $jsonGuide
    if ($hasCluster) { Write-Host "  Кластер:  $clusterHtml" -ForegroundColor Green }
    if ($hasJson) { Write-Host "  JSON:     $jsonGuide" -ForegroundColor Green }
    if ($hasHtml) { Write-Host "  Панель:   $htmlPath" -ForegroundColor Cyan }
    Write-Host ''
    Write-Host '  [1] Полное описание настройки кластера'
    Write-Host '  [2] Гайд по заполнению JSON-шаблона (предзаполненный конфиг)'
    Write-Host '  [3] Инструкция панели (ИНСТРУКЦИЯ.html)'
    Write-Host '  [4] Markdown панели'
    Write-Host '  [5] Оглавление в консоли'
    Write-Host '  [0] Назад'
    Write-Host ''
    $c = Read-Host '  Выбор'
    switch ($c) {
        '1' {
            if ($hasCluster) { Start-Process -FilePath $clusterHtml }
            else { Write-Host '  НАСТРОЙКА-КЛАСТЕРА.html не найден.' -ForegroundColor Yellow }
            Wait-TermideskKey
        }
        '2' {
            if ($hasJson) { Start-Process -FilePath $jsonGuide }
            else { Write-Host '  ГАЙД-ШАБЛОН-JSON.html не найден.' -ForegroundColor Yellow }
            Wait-TermideskKey
        }
        '3' {
            if ($hasHtml) { Start-Process -FilePath $htmlPath }
            else { Write-Host '  HTML не найден.' -ForegroundColor Yellow }
            Wait-TermideskKey
        }
        '4' {
            if ($hasMd) {
                try { Start-Process -FilePath $mdPath } catch { notepad.exe $mdPath }
            }
            else { Write-Host '  MD не найден.' -ForegroundColor Yellow }
            Wait-TermideskKey
        }
        '5' {
            Write-Host ''
            foreach ($pair in @(
                @('НАСТРОЙКА-КЛАСТЕРА.md', (Join-Path $root 'НАСТРОЙКА-КЛАСТЕРА.md')),
                @('ГАЙД-ШАБЛОН-JSON.md', (Join-Path $root 'ГАЙД-ШАБЛОН-JSON.md')),
                @('ИНСТРУКЦИЯ.md', $mdPath)
            )) {
                Write-Host "  --- $($pair[0]) ---" -ForegroundColor Yellow
                if (Test-Path -LiteralPath $pair[1]) {
                    Select-String -LiteralPath $pair[1] -Pattern '^## ' | ForEach-Object { Write-Host ("    " + $_.Line) }
                }
            }
            Write-Host ''
            Wait-TermideskKey
        }
    }
}

function Show-TermideskClusterMenu {
    Show-TermideskBanner
    Write-Host '  Отказоустойчивый кластер Termidesk 7.0' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1]  Мастер полной настройки (пошагово)'
    Write-Host '  [2]  Редактировать параметры кластера'
    Write-Host '  [3]  Сгенерировать все скрипты и конфигурации'
    Write-Host '  [4]  Выполнить шаг: PostgreSQL + RabbitMQ'
    Write-Host '  [5]  Выполнить шаг: Первый Универсальный диспетчер'
    Write-Host '  [6]  Выполнить шаг: Дополнительные диспетчеры'
    Write-Host '  [7]  Выполнить шаг: Менеджеры рабочих мест'
    Write-Host '  [8]  Выполнить шаг: Termidesk Connect (Шлюзы)'
    Write-Host '  [9]  Выполнить шаг: Балансировщик nginx'
    Write-Host '  [10] Проверка готовности кластера'
    Write-Host '  [11] Показать план развёртывания'
    Write-Host '  [0]  Назад в главное меню'
    Write-Host ''
}

function Show-TermideskDocLinks {
    Show-TermideskBanner
    Write-Host '  Документация Termidesk VDI 7.0' -ForegroundColor Yellow
    Write-Host ''
    $sections = @(
        @('Главная', ''), @('Архитектура', 'architecture'), @('HA-кластер', 'cluster'),
        @('Подготовка среды', 'prepare'), @('Балансировщик', 'distributed'),
        @('termidesk-config', 'termidesk-config'), @('OpenBao', 'openbao'),
        @('Домены', 'domains'), @('Поставщики', 'providers'), @('Фонды VDI', 'pools'),
        @('Агрегатор', 'aggregator'), @('Health Check', 'healthcheck'),
        @('Zabbix', 'zabbix'), @('Backup', 'backup'), @('Logging', 'logging'),
        @('Audit', 'audit'), @('SSL', 'ssl'), @('Gateway', 'gateway')
    )
    foreach ($s in $sections) {
        Write-Host ("  {0,-20} {1}" -f $s[0], (Get-TermideskDocLink -Section $s[1]))
    }
    Write-Host ''
    Read-Host '  Нажмите Enter для возврата'
}

function Wait-TermideskKey {
    Read-Host '  Нажмите Enter для продолжения'
}

Export-ModuleMember -Function @(
    'Show-TermideskBanner','Show-TermideskMainMenu','Show-TermideskClusterMenu',
    'Show-TermideskDocLinks','Show-TermideskInstruction','Wait-TermideskKey'
)
