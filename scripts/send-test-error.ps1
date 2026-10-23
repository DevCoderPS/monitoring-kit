# Writes ONE fake ERROR line to logs\alert-test.log so you can test the
# "Backend ERROR logs" email alert without breaking your real application.
# Usage (from the kit folder):  powershell -ExecutionPolicy Bypass -File scripts\send-test-error.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $root 'logs'
$envFile = Join-Path $root '.env'
if (Test-Path $envFile) {
    $line = Get-Content $envFile | Where-Object { $_ -match '^\s*LOG_DIR\s*=' } | Select-Object -First 1
    if ($line) {
        $v = ($line -split '=', 2)[1].Trim()
        if ($v -and $v -ne './logs') { $logDir = $v }
    }
}
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
$file = Join-Path $logDir 'alert-test.log'
$ts = [DateTime]::UtcNow.ToString('o')
$json = '{"@timestamp":"' + $ts + '","log.level":"ERROR","message":"test alert from send-test-error.ps1"}' + "`n"
$bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
# FileShare.ReadWrite so it works even while Alloy/other programs have the file open
$fs = [IO.File]::Open($file, 'Append', 'Write', 'ReadWrite')
try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Close() }
Write-Host "Wrote 1 ERROR line to $file"
Write-Host "Within ~1-2 minutes the rule 'Backend ERROR logs' should turn Firing and an email should arrive."
Write-Host "It becomes Resolved again about 5 minutes later."
