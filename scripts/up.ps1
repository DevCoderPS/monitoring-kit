# Start the monitoring kit using the on/off switches in .env  (Windows PowerShell 5.1+).
#   Usage:  powershell -ExecutionPolicy Bypass -File scripts\up.ps1
#
# 1) reads .env (EMAIL_ALERT_ENABLE=true/false ...)  2) checks what the enabled features need
# 3) writes .generated\ (alert channels, optional features such as APP_METRICS_ENABLE / POSTGRES_ENABLE / UPTIME_ENABLE) for what is enabled only
# 4) runs: docker compose up -d  and restarts prometheus/grafana ONLY if their generated config changed
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
function Die($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }
if (-not (Test-Path '.env')) { Die ".env not found. Run: Copy-Item .env.example .env  and fill it in." }

$cfg = @{}
foreach ($line in Get-Content '.env') {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
        $val = ($matches[2] -replace '\s+#.*$', '').Trim()        # drop trailing  # comment
        if ($val -match '^"(.*)"$' -or $val -match "^'(.*)'$") { $val = $matches[1] }   # drop surrounding quotes
        $cfg[$matches[1]] = $val
    }
}
function Get-Val($k) { if ($cfg.ContainsKey($k)) { return [string]$cfg[$k] } else { return '' } }
function Test-Flag($k, $default) {
    $v = Get-Val $k; if ($v -eq '') { $v = $default }
    return (@('true', '1', 'yes', 'on') -contains $v.ToLower())
}
if ((Get-Val 'GRAFANA_ADMIN_PASSWORD') -eq '') { Die "GRAFANA_ADMIN_PASSWORD is empty in .env" }

# alert channels: Flag, ReceiverName, FragmentFile (in grafana\alerting\common), DefaultOn
$channels = @(
    @{ Flag = 'EMAIL_ALERT_ENABLE'; Name = 'email-alerts'; File = 'contact-points.yaml'; Default = 'true' },
    @{ Flag = 'TELEGRAM_ALERT_ENABLE'; Name = 'telegram-alerts'; File = 'contact-points.telegram.yaml'; Default = 'false' }
)
$enabled = @()
foreach ($c in $channels) {
    if (Test-Flag $c.Flag $c.Default) { $enabled += $c; Write-Host "[ ON ] $($c.Flag)" } else { Write-Host "[ off] $($c.Flag)" }
}

if (Test-Flag 'EMAIL_ALERT_ENABLE' 'true') {
    foreach ($k in 'ALERT_EMAIL', 'SMTP_USER', 'SMTP_PASSWORD', 'SMTP_FROM') {
        if ((Get-Val $k) -eq '') { Die "EMAIL_ALERT_ENABLE=true but $k is empty in .env (fill it, or set EMAIL_ALERT_ENABLE=false)" }
    }
}

if (Test-Flag 'TELEGRAM_ALERT_ENABLE' 'false') {
    foreach ($k in 'TELEGRAM_BOT_TOKEN', 'TELEGRAM_CHAT_ID') {
        if ((Get-Val $k) -eq '') { Die "TELEGRAM_ALERT_ENABLE=true but $k is empty in .env (see README: Telegram). Or set TELEGRAM_ALERT_ENABLE=false" }
    }
    if ((Get-Val 'TELEGRAM_BOT_TOKEN') -notmatch '^[0-9]+:[A-Za-z0-9_-]+$') { Die "TELEGRAM_BOT_TOKEN does not look right (expected like 123456789:AAxxxx, no quotes/spaces)" }
    if ((Get-Val 'TELEGRAM_CHAT_ID') -notmatch '^(-?[0-9]+|@[A-Za-z0-9_]+)$') { Die "TELEGRAM_CHAT_ID does not look right (expected a number like 123456789 or -100123456789)" }
}

# alert message template
$alertTz = Get-Val 'ALERT_TIMEZONE'; if ($alertTz -eq '') { $alertTz = 'Asia/Yangon' }
if ($alertTz -notmatch '^[A-Za-z0-9_/+-]+$') { Die "ALERT_TIMEZONE must look like Asia/Yangon (or UTC)" }
$tplOn = Test-Flag 'ALERT_TEMPLATE_ENABLE' 'true'
if ($tplOn) { Write-Host "[ ON ] ALERT_TEMPLATE_ENABLE (time zone $alertTz)" } else { Write-Host "[ off] ALERT_TEMPLATE_ENABLE (Grafana default message format)" }

# optional features: validate
if (Test-Flag 'APP_METRICS_ENABLE' 'false') {
    $appTarget = Get-Val 'APP_METRICS_TARGET'; if ($appTarget -eq '') { $appTarget = 'host.docker.internal:8080' }
    $appPath = Get-Val 'APP_METRICS_PATH'; if ($appPath -eq '') { $appPath = '/actuator/prometheus' }
    $mEnv = Get-Val 'MONITORING_ENV'; if ($mEnv -eq '') { $mEnv = 'dev' }
    $mHost = Get-Val 'MONITORING_HOST'; if ($mHost -eq '') { $mHost = 'my-pc' }
    if ($appTarget -notmatch '^[A-Za-z0-9._-]+:[0-9]+$') { Die "APP_METRICS_TARGET must look like host.docker.internal:8080" }
    if ($appPath -notmatch '^/[A-Za-z0-9._/-]*$') { Die "APP_METRICS_PATH must start with / (e.g. /actuator/prometheus)" }
    if ($mEnv -notmatch '^[A-Za-z0-9._-]+$' -or $mHost -notmatch '^[A-Za-z0-9._-]+$') { Die "MONITORING_ENV / MONITORING_HOST may only contain letters, digits . _ -" }
    $appScheme = Get-Val 'APP_METRICS_SCHEME'; if ($appScheme -eq '') { $appScheme = 'http' }
    if (@('http', 'https') -notcontains $appScheme) { Die "APP_METRICS_SCHEME must be http or https" }
    $appUser = Get-Val 'APP_METRICS_USER'; $appPass = Get-Val 'APP_METRICS_PASSWORD'
    if ($appUser -ne '' -or $appPass -ne '') {
        if ($appUser -eq '' -or $appPass -eq '') { Die "APP_METRICS_USER and APP_METRICS_PASSWORD must be set together (or both empty)" }
        if ($appUser -notmatch '^[A-Za-z0-9._@-]+$') { Die "APP_METRICS_USER may only contain letters, digits . _ @ -" }
        if ($appPass -notmatch '^[^\s"''$#\\]+$') { Die "APP_METRICS_PASSWORD must not contain spaces or the characters `" ' `$ # \" }
    }
}

if (Test-Flag 'POSTGRES_ENABLE' 'false') {
    $pgHost = Get-Val 'POSTGRES_HOST'; if ($pgHost -eq '') { $pgHost = 'host.docker.internal' }
    $pgPort = Get-Val 'POSTGRES_PORT'; if ($pgPort -eq '') { $pgPort = '5432' }
    $pgDb = Get-Val 'POSTGRES_DB'; if ($pgDb -eq '') { $pgDb = 'postgres' }
    $pgUser = Get-Val 'POSTGRES_USER'; $pgPass = Get-Val 'POSTGRES_PASSWORD'
    $pgSsl = Get-Val 'POSTGRES_SSLMODE'; if ($pgSsl -eq '') { $pgSsl = 'disable' }
    $mEnv = Get-Val 'MONITORING_ENV'; if ($mEnv -eq '') { $mEnv = 'dev' }
    $mHost = Get-Val 'MONITORING_HOST'; if ($mHost -eq '') { $mHost = 'my-pc' }
    if ($pgUser -eq '' -or $pgPass -eq '') { Die "POSTGRES_ENABLE=true but POSTGRES_USER / POSTGRES_PASSWORD is empty in .env (see README: Postgres). Or set POSTGRES_ENABLE=false" }
    if ($pgHost -notmatch '^[A-Za-z0-9._-]+$') { Die "POSTGRES_HOST may only contain letters, digits . _ -" }
    if ($pgPort -notmatch '^[0-9]+$') { Die "POSTGRES_PORT must be a number" }
    if ($pgDb -notmatch '^[A-Za-z0-9._-]+$') { Die "POSTGRES_DB may only contain letters, digits . _ -" }
    if ($pgUser -notmatch '^[A-Za-z0-9._-]+$') { Die "POSTGRES_USER may only contain letters, digits . _ -" }
    if ($pgPass -notmatch '^[^\s"''$#\\]+$') { Die "POSTGRES_PASSWORD must not contain spaces or the characters `" ' `$ # \ (use a simple monitoring-only password)" }
    if (@('disable', 'require', 'verify-ca', 'verify-full') -notcontains $pgSsl) { Die "POSTGRES_SSLMODE must be disable / require / verify-ca / verify-full" }
    if ($mEnv -notmatch '^[A-Za-z0-9._-]+$' -or $mHost -notmatch '^[A-Za-z0-9._-]+$') { Die "MONITORING_ENV / MONITORING_HOST may only contain letters, digits . _ -" }
    if ($env:COMPOSE_PROFILES) { $env:COMPOSE_PROFILES = "$($env:COMPOSE_PROFILES),postgres" } else { $env:COMPOSE_PROFILES = 'postgres' }
}

if (Test-Flag 'UPTIME_ENABLE' 'false') {
    $upRaw = Get-Val 'UPTIME_URLS'
    if ($upRaw -eq '') { Die "UPTIME_ENABLE=true but UPTIME_URLS is empty in .env (e.g. UPTIME_URLS=https://example.com,http://host.docker.internal:8080/actuator/health). Or set UPTIME_ENABLE=false" }
    $upUrls = @()
    foreach ($u0 in ($upRaw -split ',')) {
        $u = $u0.Trim()
        if ($u -eq '') { continue }
        if ($u -notmatch '^https?://[A-Za-z0-9._~:/?=&%@+-]+$') { Die "UPTIME_URLS: '$u' is not a valid URL (must start with http:// or https://, no spaces/quotes; separate several with commas)" }
        # inside the container 'localhost' is the container itself -> point it at the host machine
        $u = $u -replace '^(https?://)(localhost|127\.0\.0\.1)([:/?]|$)', '$1host.docker.internal$3'
        $upUrls += $u
    }
    if ($upUrls.Count -eq 0) { Die "UPTIME_URLS has no URL" }
    $upEnv = Get-Val 'MONITORING_ENV'; if ($upEnv -eq '') { $upEnv = 'dev' }
    if ($upEnv -notmatch '^[A-Za-z0-9._-]+$') { Die "MONITORING_ENV may only contain letters, digits . _ -" }
    if ($env:COMPOSE_PROFILES) { $env:COMPOSE_PROFILES = "$($env:COMPOSE_PROFILES),uptime" } else { $env:COMPOSE_PROFILES = 'uptime' }
}

# snapshots of the generated config BEFORE regenerating (to know what changed)
function Get-Snap($dirs) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($d in $dirs) {
        if (Test-Path $d) {
            Get-ChildItem $d -Recurse -File | Sort-Object FullName | ForEach-Object { [void]$sb.Append($_.FullName).Append("`n").Append([IO.File]::ReadAllText($_.FullName)) }
        }
    }
    return $sb.ToString()
}
$gen = Join-Path $root '.generated'
$haveOld = Test-Path (Join-Path $gen 'prometheus')
$oldProm = Get-Snap @((Join-Path $gen 'prometheus'))
$oldGraf = Get-Snap @((Join-Path $gen 'alerting'), (Join-Path $gen 'dashboards'))

$out = Join-Path $root '.generated\alerting'
New-Item -ItemType Directory -Force $out | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM
function Write-Out($path, $lines) { [IO.File]::WriteAllText($path, (($lines -join "`n") + "`n"), $utf8) }

# contact points
if ($enabled.Count -gt 0) {
    $cp = @('# GENERATED by scripts/up.ps1 - do not edit (edit grafana/alerting/common/* and .env instead)', 'apiVersion: 1', 'contactPoints:')
    foreach ($c in $enabled) {
        $all = [IO.File]::ReadAllLines((Join-Path $root "grafana\alerting\common\$($c.File)"), [Text.Encoding]::UTF8)
        $idx = [Array]::FindIndex($all, [Predicate[string]] { param($l) $l -match '^contactPoints:' })
        if ($idx -lt 0) { Die "grafana/alerting/common/$($c.File) has no 'contactPoints:' line" }
        $body = @($all[($idx + 1)..($all.Count - 1)])
        if (-not $tplOn) { $body = @($body | Where-Object { $_ -notmatch '#tpl' }) }
        $cp += $body
    }
} else {
    $cp = @('# GENERATED by scripts/up.ps1 - no alert channel enabled', 'apiVersion: 1')
}
# Telegram chat id is written literally (Grafana turns "${VAR}" numbers into a number and then rejects it)
$cp = @($cp | ForEach-Object { $_.Replace('@@TELEGRAM_CHAT_ID@@', (Get-Val 'TELEGRAM_CHAT_ID')) })
Write-Out (Join-Path $out 'contact-points.yaml') $cp

# alert message templates (always written; empty when ALERT_TEMPLATE_ENABLE=false)
if ($tplOn) {
    $tl = [IO.File]::ReadAllText((Join-Path $root 'grafana\alerting\common\templates.yaml'), [Text.Encoding]::UTF8).Replace('@@ALERT_TIMEZONE@@', $alertTz).Replace("`r`n", "`n")
    [IO.File]::WriteAllText((Join-Path $out 'templates.yaml'), ("# GENERATED by scripts/up.ps1 - do not edit (edit grafana/alerting/common/templates.yaml and .env instead)`n" + $tl), $utf8)
} else {
    Write-Out (Join-Path $out 'templates.yaml') @('# GENERATED by scripts/up.ps1 - ALERT_TEMPLATE_ENABLE is off', 'apiVersion: 1')
}

# policy
$timing = @(Get-Content 'grafana\alerting\common\policies.yaml' -Encoding UTF8 | Where-Object { $_ -match '^\s+(group_by|group_wait|group_interval|repeat_interval):' })
$pol = @('# GENERATED by scripts/up.ps1 - do not edit', 'apiVersion: 1', 'policies:', '  - orgId: 1')
if ($enabled.Count -eq 0) {
    $pol += '    receiver: grafana-default-email'   # built-in Grafana receiver (nothing enabled)
    $pol += $timing
} else {
    $pol += "    receiver: $($enabled[0].Name)"
    $pol += $timing
    if ($enabled.Count -gt 1) {
        $pol += '    routes:'
        foreach ($c in $enabled) { $pol += "      - receiver: $($c.Name)"; $pol += '        continue: true' }
    }
}
Write-Out (Join-Path $out 'policies.yaml') $pol

$names = if ($enabled.Count -gt 0) { ($enabled | ForEach-Object { $_.Name }) -join ', ' } else { 'none' }
Write-Host "[ OK ] generated .generated\alerting (channels: $names)"
# optional feature: DTM app metrics (Spring Boot Actuator -> Prometheus)
# NOTE: files are rewritten in place (never delete+recreate the folders) because they are bind-mounted into containers
$scrapeDir = Join-Path $gen 'prometheus\scrape.d'; $dashDir = Join-Path $gen 'dashboards\app'
New-Item -ItemType Directory -Force $scrapeDir | Out-Null
New-Item -ItemType Directory -Force $dashDir | Out-Null
Get-ChildItem $scrapeDir -File | Remove-Item -Force
Get-ChildItem $dashDir -File | Remove-Item -Force
$rulesApp = Join-Path $out 'rules-app.yaml'
Write-Out $rulesApp @('# GENERATED by scripts/up.ps1 - APP_METRICS_ENABLE is off', 'apiVersion: 1')
if (Test-Flag 'APP_METRICS_ENABLE' 'false') {
    $fx = Join-Path $root 'features\app-metrics'
    $sc = [IO.File]::ReadAllText((Join-Path $fx 'scrape.yml'), [Text.Encoding]::UTF8)
    if ($appUser -ne '') { $authBlock = "    basic_auth:`n      username: '$appUser'`n      password: '$appPass'`n" } else { $authBlock = '' }
    $sc = $sc.Replace("@@APP_METRICS_AUTH@@`r`n", $authBlock).Replace("@@APP_METRICS_AUTH@@`n", $authBlock)
    $sc = $sc.Replace('@@APP_METRICS_TARGET@@', $appTarget).Replace('@@APP_METRICS_PATH@@', $appPath).Replace('@@APP_METRICS_SCHEME@@', $appScheme).Replace('@@MONITORING_ENV@@', $mEnv).Replace('@@MONITORING_HOST@@', $mHost)
    [IO.File]::WriteAllText((Join-Path $scrapeDir 'app-metrics.yml'), $sc, $utf8)
    [IO.File]::WriteAllText((Join-Path $dashDir 'app-metrics.json'), [IO.File]::ReadAllText((Join-Path $fx 'dashboard.json'), [Text.Encoding]::UTF8), $utf8)
    [IO.File]::WriteAllText($rulesApp, [IO.File]::ReadAllText((Join-Path $fx 'rules.yaml'), [Text.Encoding]::UTF8), $utf8)
    Write-Host "[ ON ] APP_METRICS_ENABLE -> ${appScheme}://$appTarget$appPath"
} else {
    Write-Host "[ off] APP_METRICS_ENABLE"
}
$rulesPg = Join-Path $out 'rules-postgres.yaml'
Write-Out $rulesPg @('# GENERATED by scripts/up.ps1 - POSTGRES_ENABLE is off', 'apiVersion: 1')
if (Test-Flag 'POSTGRES_ENABLE' 'false') {
    $fx = Join-Path $root 'features\postgres'
    $sc = [IO.File]::ReadAllText((Join-Path $fx 'scrape.yml'), [Text.Encoding]::UTF8)
    $sc = $sc.Replace('@@MONITORING_ENV@@', $mEnv).Replace('@@MONITORING_HOST@@', $mHost)
    [IO.File]::WriteAllText((Join-Path $scrapeDir 'postgres.yml'), $sc, $utf8)
    [IO.File]::WriteAllText((Join-Path $dashDir 'postgres.json'), [IO.File]::ReadAllText((Join-Path $fx 'dashboard.json'), [Text.Encoding]::UTF8), $utf8)
    [IO.File]::WriteAllText($rulesPg, [IO.File]::ReadAllText((Join-Path $fx 'rules.yaml'), [Text.Encoding]::UTF8), $utf8)
    Write-Host "[ ON ] POSTGRES_ENABLE -> ${pgHost}:$pgPort/$pgDb (user $pgUser)"
} else {
    Write-Host "[ off] POSTGRES_ENABLE"
}
$rulesUp = Join-Path $out 'rules-uptime.yaml'
Write-Out $rulesUp @('# GENERATED by scripts/up.ps1 - UPTIME_ENABLE is off', 'apiVersion: 1')
if (Test-Flag 'UPTIME_ENABLE' 'false') {
    $fx = Join-Path $root 'features\uptime'
    $sl = @('# GENERATED by scripts/up.ps1 - do not edit (edit UPTIME_URLS in .env)', 'scrape_configs:', '  - job_name: uptime', '    metrics_path: /probe', '    params:', '      module: [http_2xx]', '    static_configs:', '      - targets:')
    foreach ($u in $upUrls) { $sl += "          - '$u'" }
    $sl += @('        labels:', "          env: '$upEnv'", '    relabel_configs:', '      - source_labels: [__address__]', '        target_label: __param_target', '      - source_labels: [__param_target]', '        target_label: instance', '      - target_label: __address__', '        replacement: blackbox-exporter:9115')
    Write-Out (Join-Path $scrapeDir 'uptime.yml') $sl
    [IO.File]::WriteAllText((Join-Path $dashDir 'uptime.json'), [IO.File]::ReadAllText((Join-Path $fx 'dashboard.json'), [Text.Encoding]::UTF8), $utf8)
    [IO.File]::WriteAllText($rulesUp, [IO.File]::ReadAllText((Join-Path $fx 'rules.yaml'), [Text.Encoding]::UTF8), $utf8)
    Write-Host "[ ON ] UPTIME_ENABLE -> $($upUrls.Count) URL(s): $($upUrls -join ' ')"
} else {
    Write-Host "[ off] UPTIME_ENABLE"
}
$newProm = Get-Snap @((Join-Path $gen 'prometheus'))
$newGraf = Get-Snap @((Join-Path $gen 'alerting'), (Join-Path $gen 'dashboards'))

# exporter container is only part of the stack when POSTGRES_ENABLE=true; remove it when switched off
if (-not (Test-Flag 'POSTGRES_ENABLE' 'false')) { $ErrorActionPreference = 'Continue'; & docker compose --profile postgres rm -sf postgres-exporter 2>&1 | Out-Null; $ErrorActionPreference = 'Stop' }
if (-not (Test-Flag 'UPTIME_ENABLE' 'false')) { $ErrorActionPreference = 'Continue'; & docker compose --profile uptime rm -sf blackbox-exporter 2>&1 | Out-Null; $ErrorActionPreference = 'Stop' }
& docker compose up -d @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($haveOld) {
    if ($oldProm -ne $newProm) { Write-Host "[ .. ] Prometheus config changed -> restarting prometheus"; & docker compose restart prometheus }
    if ($oldGraf -ne $newGraf) { Write-Host "[ .. ] Grafana provisioning changed -> restarting grafana"; & docker compose restart grafana }
}
exit $LASTEXITCODE
