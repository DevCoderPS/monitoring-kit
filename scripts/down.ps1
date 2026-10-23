# Stop and remove all monitoring containers (including optional ones). Data volumes are kept.
#   Usage: powershell -ExecutionPolicy Bypass -File scripts\down.ps1      (add -v to ALSO delete the stored data)
Set-Location (Split-Path -Parent $PSScriptRoot)
& docker compose --profile '*' down @args
exit $LASTEXITCODE
