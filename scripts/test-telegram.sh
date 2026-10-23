#!/usr/bin/env bash
# Sends ONE test message through your Telegram bot (independent of Grafana), so you can verify
# TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID before enabling the alert channel.
#   bash scripts/test-telegram.sh
# If TELEGRAM_CHAT_ID is empty it lists the chat ids that talked to the bot (send the bot a message first).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
getv() { grep -E "^[[:space:]]*$1[[:space:]]*=" "$ROOT/.env" 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' || true; }
TOKEN="$(getv TELEGRAM_BOT_TOKEN)"; CHAT="$(getv TELEGRAM_CHAT_ID)"
API="${TELEGRAM_API_BASE:-https://api.telegram.org}"
[ -n "$TOKEN" ] || { echo "[FAIL] TELEGRAM_BOT_TOKEN is empty in .env" >&2; exit 1; }
if [ -z "$CHAT" ]; then
  echo "TELEGRAM_CHAT_ID is empty. Chats that messaged the bot (send it a message first, or add it to a group and write there):"
  r="$(curl -fsS -m 20 "$API/bot$TOKEN/getUpdates")" || { echo "[FAIL] Telegram API call failed (token wrong?)" >&2; exit 1; }
  ids="$(printf '%s' "$r" | grep -o '"chat":{"id":-\?[0-9]*' | sed 's/.*://' | sort -u)"
  [ -n "$ids" ] && printf '  chat id: %s\n' $ids || echo "  (none yet)"
  echo "Put the number in .env as TELEGRAM_CHAT_ID=..."
  exit 0
fi
r="$(curl -sS -m 20 --data-urlencode "chat_id=$CHAT" --data-urlencode "text=Monitoring kit: Telegram test message OK" "$API/bot$TOKEN/sendMessage")" || { echo "[FAIL] could not reach Telegram" >&2; exit 1; }
if printf '%s' "$r" | grep -q '"ok":true'; then echo "[ OK ] test message sent - check your Telegram"; else echo "[FAIL] Telegram replied: $r" >&2; exit 1; fi
