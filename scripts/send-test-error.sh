#!/usr/bin/env bash
# Writes ONE fake ERROR line to <LOG_DIR>/alert-test.log to test the "Backend ERROR logs" email alert
# without touching your real application.   Usage (from the kit folder):  bash scripts/send-test-error.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs"
if [ -f "$ROOT/.env" ]; then
  v="$(grep -E '^[[:space:]]*LOG_DIR[[:space:]]*=' "$ROOT/.env" | head -n1 | cut -d= -f2- | tr -d '[:space:]' || true)"
  if [ -n "${v:-}" ] && [ "$v" != "./logs" ]; then LOG_DIR="$v"; fi
fi
mkdir -p "$LOG_DIR"
printf '{"@timestamp":"%s","log.level":"ERROR","message":"test alert from send-test-error.sh"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG_DIR/alert-test.log"
echo "Wrote 1 ERROR line to $LOG_DIR/alert-test.log"
echo "Within ~1-2 minutes the rule 'Backend ERROR logs' should turn Firing and an email should arrive."
echo "It becomes Resolved again about 5 minutes later."
