#!/usr/bin/env bash
# Health check for the whole kit. Run AFTER "docker compose up -d" (wait ~30 seconds).
# Usage (from the kit folder):  bash scripts/check.sh        (needs: curl)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/.env" ] || { echo "[FAIL] .env not found. Copy .env.example to .env first."; exit 1; }
getv() { grep -E "^[[:space:]]*$1[[:space:]]*=" "$ROOT/.env" | head -n1 | cut -d= -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
PORT="$(getv GRAFANA_PORT)"; PORT="${PORT:-3000}"
USER_="$(getv GRAFANA_ADMIN_USER)"; USER_="${USER_:-admin}"
PASS="$(getv GRAFANA_ADMIN_PASSWORD)"
BASE="http://127.0.0.1:${PORT}"
FAIL=0
ok()  { printf '[ OK ] %s\n' "$*"; }
bad() { printf '[FAIL] %s\n' "$*"; FAIL=$((FAIL+1)); }
api() { curl -fsS -m 15 -u "${USER_}:${PASS}" "$BASE$1"; }

echo "--- containers"; (cd "$ROOT" && docker compose ps)
echo "--- checks"
if v="$(curl -fsS -m 15 "$BASE/api/health")"; then ok "Grafana is up"; else bad "Grafana not reachable at $BASE (docker compose logs grafana)"; fi

for uid in dtm-prometheus dtm-loki; do
  if r="$(api "/api/datasources/uid/$uid/health")" && echo "$r" | grep -q '"status":"OK"'; then ok "Data source $uid healthy"
  else bad "Data source $uid not healthy (or login failed: check GRAFANA_ADMIN_PASSWORD in .env)"; fi
done

if r="$(api "/api/datasources/proxy/uid/dtm-prometheus/api/v1/query?query=up")"; then
  up="$(echo "$r" | grep -o '"1"\]' | wc -l)"; down="$(echo "$r" | grep -o '"0"\]' | wc -l)"
  [ "$down" -eq 0 ] && ok "Prometheus targets UP: $up" || bad "Prometheus targets DOWN: $down  (UP: $up)"
else bad "Could not query Prometheus"; fi

if r="$(api "/api/datasources/proxy/uid/dtm-loki/loki/api/v1/labels")"; then
  echo "$r" | grep -q '"data":\[\]' && echo "[WARN] Loki has no logs yet. Put a *.log file in the logs folder (see README)." || ok "Loki has logs"
else bad "Could not query Loki"; fi

if r="$(api "/api/v1/provisioning/alert-rules")"; then
  n="$(echo "$r" | grep -o '"title"' | wc -l)"; [ "$n" -ge 1 ] && ok "$n alert rules loaded" || bad "No alert rules loaded (docker compose logs grafana)"
else bad "Could not read alert rules"; fi

em="$(getv EMAIL_ALERT_ENABLE | tr '[:upper:]' '[:lower:]')"; em="${em:-true}"
if r="$(api "/api/v1/provisioning/contact-points")"; then
  case "$em" in
    true|1|yes|on) echo "$r" | grep -q '"type":"email"' && ok "Email contact point loaded" || bad "No email contact point loaded" ;;
    *) echo "[ off] EMAIL_ALERT_ENABLE=false - email contact point not expected" ;;
  esac
else bad "Could not read contact points"; fi
tg="$(getv TELEGRAM_ALERT_ENABLE | tr '[:upper:]' '[:lower:]')"
case "$tg" in
  true|1|yes|on)
    if r="$(api "/api/v1/provisioning/contact-points")" && echo "$r" | grep -q '"type":"telegram"'; then ok "Telegram contact point loaded"; else bad "No Telegram contact point loaded (docker compose logs grafana)"; fi ;;
esac

if r="$(api "/api/search?type=dash-db")"; then ok "Dashboards: $(echo "$r" | grep -o '"title":"[^"]*"' | cut -d'"' -f4 | paste -sd'|' -)"; else bad "Could not list dashboards"; fi

if [ "$FAIL" -eq 0 ]; then echo; echo "ALL CHECKS PASSED"; else echo; echo "$FAIL check(s) failed"; exit 1; fi
