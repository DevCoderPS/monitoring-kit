# Sends ONE test message through your Telegram bot (independent of Grafana), to verify
# TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID before enabling the alert channel.
#   powershell -ExecutionPolicy Bypass -File scripts\test-telegram.ps1
# If TELEGRAM_CHAT_ID is empty it lists the chat ids that talked to the bot (send the bot a message first).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$cfg = @{}
if (Test-Path (Join-Path $root '.env')) {
    foreach ($line in Get-Content (Join-Path $root '.env')) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') { $cfg[$matches[1]] = $matches[2].Trim() }
    }
}
$token = [string]$cfg['TELEGRAM_BOT_TOKEN']; $chat = [string]$cfg['TELEGRAM_CHAT_ID']
$api = if ($env:TELEGRAM_API_BASE) { $env:TELEGRAM_API_BASE } else { 'https://api.telegram.org' }
if ($token -eq '') { Write-Host "[FAIL] TELEGRAM_BOT_TOKEN is empty in .env" -ForegroundColor Red; exit 1 }
try {
    if ($chat -eq '') {
        Write-Host "TELEGRAM_CHAT_ID is empty. Chats that messaged the bot (send it a message first, or add it to a group and write there):"
        $r = Invoke-RestMethod "$api/bot$token/getUpdates" -TimeoutSec 20
        $ids = @($r.result | ForEach-Object { if ($_.message) { $_.message.chat.id } elseif ($_.channel_post) { $_.channel_post.chat.id } } | Sort-Object -Unique)
        if ($ids.Count -gt 0) { foreach ($i in $ids) { Write-Host "  chat id: $i" } } else { Write-Host "  (none yet)" }
        Write-Host "Put the number in .env as TELEGRAM_CHAT_ID=..."
        exit 0
    }
    $r = Invoke-RestMethod "$api/bot$token/sendMessage" -Method Post -TimeoutSec 20 -Body @{ chat_id = $chat; text = 'Monitoring kit: Telegram test message OK' }
    if ($r.ok) { Write-Host "[ OK ] test message sent - check your Telegram" -ForegroundColor Green } else { Write-Host "[FAIL] Telegram said not ok" -ForegroundColor Red; exit 1 }
} catch {
    Write-Host "[FAIL] Telegram call failed: $($_.Exception.Message)" -ForegroundColor Red; exit 1
}
