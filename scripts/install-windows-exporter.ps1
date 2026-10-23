# Installs windows_exporter (CPU / RAM / Disk / Network metrics) as a Windows service.
# Run in an ADMINISTRATOR PowerShell:
#     powershell -ExecutionPolicy Bypass -File scripts\install-windows-exporter.ps1
#Requires -RunAsAdministrator
param([string]$Version = '0.31.3')
$ErrorActionPreference = 'Stop'

if (Get-Service windows_exporter -ErrorAction SilentlyContinue) {
    Write-Host "windows_exporter is already installed:" -ForegroundColor Yellow
    Get-Service windows_exporter
    Write-Host "Nothing to do. (To upgrade, uninstall it first from 'Apps & features'.)"
    exit 0
}

$msi = Join-Path $env:TEMP "windows_exporter-$Version-amd64.msi"
$log = Join-Path $env:TEMP "windows_exporter-install.log"
$url = "https://github.com/prometheus-community/windows_exporter/releases/download/v$Version/windows_exporter-$Version-amd64.msi"

Write-Host "Downloading $url"
Invoke-WebRequest $url -OutFile $msi -UseBasicParsing

Write-Host "Installing (log: $log) ..."
$args = @('/i', "`"$msi`"", '/qn', '/l*v', "`"$log`"",
          'ENABLED_COLLECTORS=cpu,logical_disk,memory,net,os,system', 'LISTEN_PORT=9182')
$p = Start-Process msiexec.exe -ArgumentList $args -Wait -PassThru
if ($p.ExitCode -notin 0, 3010) { throw "MSI install failed, exit code $($p.ExitCode). See $log" }

Start-Sleep -Seconds 5
Get-Service windows_exporter

try {
    $r = Invoke-WebRequest http://localhost:9182/metrics -UseBasicParsing
    Write-Host "OK: http://localhost:9182/metrics answered with HTTP $($r.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Service installed but /metrics did not answer yet. Wait 10 seconds and open http://localhost:9182/metrics in a browser." -ForegroundColor Yellow
}
Write-Host "Next step: docker compose up -d"
