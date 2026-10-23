# Health check for the whole kit. Run AFTER "docker compose up -d" (wait ~30 seconds).
# Usage (from the kit folder):  powershell -ExecutionPolicy Bypass -File scripts\check.ps1
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
if (-not (Test-Path $envFile)) { Write-Host "[FAIL] .env not found. Copy .env.example to .env first." -ForegroundColor Red; exit 1 }
$cfg = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') { $cfg[$matches[1]] = $matches[2].Trim() }
}
$port = if ($cfg['GRAFANA_PORT']) { $cfg['GRAFANA_PORT'] } else { '3000' }
$user = if ($cfg['GRAFANA_ADMIN_USER']) { $cfg['GRAFANA_ADMIN_USER'] } else { 'admin' }
$base = "http://127.0.0.1:$port"
$auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($user):$($cfg['GRAFANA_ADMIN_PASSWORD'])"))
$h = @{ Authorization = "Basic $auth" }
$script:fail = 0
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Bad($m)  { Write-Host "[FAIL] $m" -ForegroundColor Red; $script:fail++ }
function Get-Json($path) { Invoke-RestMethod "$base$path" -Headers $h -TimeoutSec 15 }

Push-Location $root
Write-Host "--- containers"
docker compose ps
Pop-Location

Write-Host "--- checks"
try { $r = Invoke-RestMethod "$base/api/health" -TimeoutSec 15; Ok "Grafana is up (version $($r.version))" } catch { Bad "Grafana not reachable at $base (see: docker compose logs grafana)" }

foreach ($uid in 'dtm-prometheus', 'dtm-loki') {
    try {
        $r = Get-Json "/api/datasources/uid/$uid/health"
        if ($r.status -eq 'OK') { Ok "Data source $uid healthy" } else { Bad "Data source $uid : $($r.message)" }
    } catch { Bad "Data source $uid not found or login failed (check GRAFANA_ADMIN_PASSWORD in .env)" }
}

try {
    $r = Get-Json '/api/datasources/proxy/uid/dtm-prometheus/api/v1/query?query=up'
    foreach ($s in $r.data.result) {
        $name = "$($s.metric.job) $($s.metric.instance)"
        if ($s.value[1] -eq '1') { Ok "Prometheus target UP: $name" } else { Bad "Prometheus target DOWN: $name" }
    }
} catch { Bad "Could not query Prometheus targets" }

try {
    $r = Get-Json '/api/datasources/proxy/uid/dtm-loki/loki/api/v1/labels'
    if ($r.data.Count -gt 0) { Ok "Loki has logs. Labels: $($r.data -join ', ')" }
    else { Write-Host "[WARN] Loki has no logs yet. Put a *.log file in the logs folder (see README)." -ForegroundColor Yellow }
} catch { Bad "Could not query Loki" }

try {
    $rules = Get-Json '/api/v1/provisioning/alert-rules'
    if (@($rules).Count -ge 1) { Ok "$(@($rules).Count) alert rules loaded: $((@($rules) | ForEach-Object { $_.title }) -join ' | ')" } else { Bad "No alert rules loaded (see: docker compose logs grafana)" }
} catch { Bad "Could not read alert rules" }

$emailOn = -not (@('false', '0', 'no', 'off') -contains ([string]$cfg['EMAIL_ALERT_ENABLE']).ToLower())
try {
    $cp = Get-Json '/api/v1/provisioning/contact-points'
    if (-not $emailOn) { Write-Host "[ off] EMAIL_ALERT_ENABLE=false - email contact point not expected" -ForegroundColor Yellow }
    elseif (@($cp | Where-Object { $_.type -eq 'email' }).Count -ge 1) { Ok "Email contact point loaded: $((@($cp) | ForEach-Object { $_.name }) -join ', ')" } else { Bad "No email contact point loaded" }
} catch { Bad "Could not read contact points" }

if (@('true', '1', 'yes', 'on') -contains ([string]$cfg['TELEGRAM_ALERT_ENABLE']).ToLower()) {
    try {
        $cp2 = Get-Json '/api/v1/provisioning/contact-points'
        if (@($cp2 | Where-Object { $_.type -eq 'telegram' }).Count -ge 1) { Ok "Telegram contact point loaded" } else { Bad "No Telegram contact point loaded (see: docker compose logs grafana)" }
    } catch { Bad "Could not read contact points" }
}

try {
    $d = Get-Json '/api/search?type=dash-db'
    Ok "Dashboards: $((@($d) | ForEach-Object { $_.title }) -join ' | ')"
} catch { Bad "Could not list dashboards" }

if ($script:fail -eq 0) { Write-Host "`nALL CHECKS PASSED" -ForegroundColor Green } else { Write-Host "`n$($script:fail) check(s) failed" -ForegroundColor Red; exit 1 }
