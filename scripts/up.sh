#!/usr/bin/env bash
# Start the monitoring kit using the on/off switches in .env  (Linux / Mac).
#   Usage (from anywhere):  bash scripts/up.sh          (extra args go to "docker compose up -d")
#
# What it does:
#   1) reads .env  (EMAIL_ALERT_ENABLE=true/false ...)
#   2) checks the settings that the enabled features need
#   3) writes .generated/  (alert channels, optional features such as APP_METRICS_ENABLE / POSTGRES_ENABLE / UPTIME_ENABLE) for what is enabled only
#   4) runs: docker compose up -d   and restarts prometheus/grafana ONLY if their generated config changed
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
die() { echo "[FAIL] $*" >&2; exit 1; }
[ -f .env ] || die ".env not found. Run: cp .env.example .env  and fill it in."

# value = text after "=", without trailing  # comment  and without surrounding quotes
getv() { grep -E "^[[:space:]]*$1[[:space:]]*=" .env | tail -n1 | cut -d= -f2- | tr -d '\r' | sed -E 's/[[:space:]]+#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' || true; }
is_true() { case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in true|1|yes|on) return 0 ;; *) return 1 ;; esac; }
flag() { local v; v="$(getv "$1")"; v="${v:-$2}"; is_true "$v"; }   # flag NAME DEFAULT

[ -n "$(getv GRAFANA_ADMIN_PASSWORD)" ] || die "GRAFANA_ADMIN_PASSWORD is empty in .env"

# ---- alert channels:  FLAG | receiver name | fragment file (in grafana/alerting/common) ----
CHANNELS=(
  "EMAIL_ALERT_ENABLE|email-alerts|contact-points.yaml"
  "TELEGRAM_ALERT_ENABLE|telegram-alerts|contact-points.telegram.yaml"
)
DEFAULT_ON="EMAIL_ALERT_ENABLE"   # flags that are ON when missing from .env

enabled_names=(); enabled_files=()
for c in "${CHANNELS[@]}"; do
  IFS='|' read -r f name file <<<"$c"
  d=false; case " $DEFAULT_ON " in *" $f "*) d=true ;; esac
  if flag "$f" "$d"; then enabled_names+=("$name"); enabled_files+=("$file"); echo "[ ON ] $f"; else echo "[ off] $f"; fi
done

# ---- per-channel checks ----
if flag EMAIL_ALERT_ENABLE true; then
  for k in ALERT_EMAIL SMTP_USER SMTP_PASSWORD SMTP_FROM; do
    [ -n "$(getv $k)" ] || die "EMAIL_ALERT_ENABLE=true but $k is empty in .env (fill it, or set EMAIL_ALERT_ENABLE=false)"
  done
fi

if flag TELEGRAM_ALERT_ENABLE false; then
  for k in TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID; do
    [ -n "$(getv $k)" ] || die "TELEGRAM_ALERT_ENABLE=true but $k is empty in .env (see README: Telegram). Or set TELEGRAM_ALERT_ENABLE=false"
  done
  printf '%s' "$(getv TELEGRAM_BOT_TOKEN)" | grep -Eq '^[0-9]+:[A-Za-z0-9_-]+$' || die "TELEGRAM_BOT_TOKEN does not look right (expected like 123456789:AAxxxx, no quotes/spaces)"
  printf '%s' "$(getv TELEGRAM_CHAT_ID)" | grep -Eq '^(-?[0-9]+|@[A-Za-z0-9_]+)$' || die "TELEGRAM_CHAT_ID does not look right (expected a number like 123456789 or -100123456789)"
fi

# ---- alert message template ----
ALERT_TZ="$(getv ALERT_TIMEZONE)"; ALERT_TZ="${ALERT_TZ:-Asia/Yangon}"
printf '%s' "$ALERT_TZ" | grep -Eq '^[A-Za-z0-9_/+-]+$' || die "ALERT_TIMEZONE must look like Asia/Yangon (or UTC)"
if flag ALERT_TEMPLATE_ENABLE true; then TPL_ON=1; echo "[ ON ] ALERT_TEMPLATE_ENABLE (time zone $ALERT_TZ)"; else TPL_ON=0; echo "[ off] ALERT_TEMPLATE_ENABLE (Grafana default message format)"; fi

# ---- optional features checks ----
if flag APP_METRICS_ENABLE false; then
  APP_TARGET="$(getv APP_METRICS_TARGET)"; APP_TARGET="${APP_TARGET:-host.docker.internal:8080}"
  APP_PATH="$(getv APP_METRICS_PATH)"; APP_PATH="${APP_PATH:-/actuator/prometheus}"
  printf '%s' "$APP_TARGET" | grep -Eq '^[A-Za-z0-9._-]+:[0-9]+$' || die "APP_METRICS_TARGET must look like host.docker.internal:8080"
  printf '%s' "$APP_PATH" | grep -Eq '^/[A-Za-z0-9._/-]*$' || die "APP_METRICS_PATH must start with / (e.g. /actuator/prometheus)"
  M_ENV="$(getv MONITORING_ENV)"; M_ENV="${M_ENV:-dev}"; M_HOST="$(getv MONITORING_HOST)"; M_HOST="${M_HOST:-my-pc}"
  printf '%s %s' "$M_ENV" "$M_HOST" | grep -Eq '^[A-Za-z0-9._-]+ [A-Za-z0-9._-]+$' || die "MONITORING_ENV / MONITORING_HOST may only contain letters, digits . _ -"
  APP_SCHEME="$(getv APP_METRICS_SCHEME)"; APP_SCHEME="${APP_SCHEME:-http}"
  case "$APP_SCHEME" in http|https) ;; *) die "APP_METRICS_SCHEME must be http or https" ;; esac
  APP_USER="$(getv APP_METRICS_USER)"; APP_PASS="$(getv APP_METRICS_PASSWORD)"
  if [ -n "$APP_USER$APP_PASS" ]; then
    [ -n "$APP_USER" ] && [ -n "$APP_PASS" ] || die "APP_METRICS_USER and APP_METRICS_PASSWORD must be set together (or both empty)"
    printf '%s' "$APP_USER" | grep -Eq '^[A-Za-z0-9._@-]+$' || die "APP_METRICS_USER may only contain letters, digits . _ @ -"
    printf '%s' "$APP_PASS" | grep -Eq '^[^[:space:]"'"'"'$#\\]+$' || die "APP_METRICS_PASSWORD must not contain spaces or the characters \" ' \$ # \\"
  fi
fi

if flag POSTGRES_ENABLE false; then
  PG_HOST="$(getv POSTGRES_HOST)"; PG_HOST="${PG_HOST:-host.docker.internal}"
  PG_PORT="$(getv POSTGRES_PORT)"; PG_PORT="${PG_PORT:-5432}"
  PG_DB="$(getv POSTGRES_DB)"; PG_DB="${PG_DB:-postgres}"
  PG_USER="$(getv POSTGRES_USER)"; PG_PASS="$(getv POSTGRES_PASSWORD)"
  [ -n "$PG_USER" ] && [ -n "$PG_PASS" ] || die "POSTGRES_ENABLE=true but POSTGRES_USER / POSTGRES_PASSWORD is empty in .env (see README: Postgres). Or set POSTGRES_ENABLE=false"
  printf '%s' "$PG_HOST" | grep -Eq '^[A-Za-z0-9._-]+$' || die "POSTGRES_HOST may only contain letters, digits . _ -"
  printf '%s' "$PG_PORT" | grep -Eq '^[0-9]+$' || die "POSTGRES_PORT must be a number"
  printf '%s' "$PG_DB" | grep -Eq '^[A-Za-z0-9._-]+$' || die "POSTGRES_DB may only contain letters, digits . _ -"
  printf '%s' "$PG_USER" | grep -Eq '^[A-Za-z0-9._-]+$' || die "POSTGRES_USER may only contain letters, digits . _ -"
  printf '%s' "$PG_PASS" | grep -Eq '^[^[:space:]"'"'"'$#\\]+$' || die "POSTGRES_PASSWORD must not contain spaces or the characters \" ' \$ # \\ (use a simple monitoring-only password)"
  PG_SSL="$(getv POSTGRES_SSLMODE)"; PG_SSL="${PG_SSL:-disable}"
  case "$PG_SSL" in disable|require|verify-ca|verify-full) ;; *) die "POSTGRES_SSLMODE must be disable / require / verify-ca / verify-full" ;; esac
  M_ENV="$(getv MONITORING_ENV)"; M_ENV="${M_ENV:-dev}"; M_HOST="$(getv MONITORING_HOST)"; M_HOST="${M_HOST:-my-pc}"
  printf '%s %s' "$M_ENV" "$M_HOST" | grep -Eq '^[A-Za-z0-9._-]+ [A-Za-z0-9._-]+$' || die "MONITORING_ENV / MONITORING_HOST may only contain letters, digits . _ -"
  export COMPOSE_PROFILES="${COMPOSE_PROFILES:+$COMPOSE_PROFILES,}postgres"
fi

if flag UPTIME_ENABLE false; then
  UP_RAW="$(getv UPTIME_URLS)"
  [ -n "$UP_RAW" ] || die "UPTIME_ENABLE=true but UPTIME_URLS is empty in .env (e.g. UPTIME_URLS=https://example.com,http://host.docker.internal:8080/actuator/health). Or set UPTIME_ENABLE=false"
  UP_URLS=()
  IFS=',' read -r -a _up_arr <<<"$UP_RAW"
  for u in "${_up_arr[@]}"; do
    u="$(printf '%s' "$u" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$u" ] || continue
    printf '%s' "$u" | grep -Eq '^https?://[A-Za-z0-9._~:/?=&%@+-]+$' || die "UPTIME_URLS: '$u' is not a valid URL (must start with http:// or https://, no spaces/quotes; separate several with commas)"
    # inside the container 'localhost' is the container itself -> point it at the host machine
    u="$(printf '%s' "$u" | sed -E 's#^(https?://)(localhost|127\.0\.0\.1)([:/?]|$)#\1host.docker.internal\3#')"
    UP_URLS+=("$u")
  done
  [ "${#UP_URLS[@]}" -gt 0 ] || die "UPTIME_URLS has no URL"
  M_ENV="$(getv MONITORING_ENV)"; M_ENV="${M_ENV:-dev}"
  printf '%s' "$M_ENV" | grep -Eq '^[A-Za-z0-9._-]+$' || die "MONITORING_ENV may only contain letters, digits . _ -"
  export COMPOSE_PROFILES="${COMPOSE_PROFILES:+$COMPOSE_PROFILES,}uptime"
fi

# ---- snapshots of the generated config BEFORE regenerating (to know what changed) ----
snap() { local d; for d in "$@"; do if [ -d "$d" ]; then find "$d" -type f | sort | xargs -r cat; fi; done | sha256sum | cut -d' ' -f1; }
if [ -d .generated/prometheus ]; then have_old=1; else have_old=0; fi
old_prom="$(snap .generated/prometheus)"; old_graf="$(snap .generated/alerting .generated/dashboards)"

# ---- generate ----
OUT=.generated/alerting; mkdir -p "$OUT"
{
  echo "# GENERATED by scripts/up.sh - do not edit (edit grafana/alerting/common/* and .env instead)"
  echo "apiVersion: 1"
  echo "contactPoints:"
  for file in "${enabled_files[@]+"${enabled_files[@]}"}"; do
    if [ "$TPL_ON" -eq 1 ]; then
      sed -n '/^contactPoints:/,$p' "grafana/alerting/common/$file" | tail -n +2
    else
      sed -n '/^contactPoints:/,$p' "grafana/alerting/common/$file" | tail -n +2 | { grep -v '#tpl' || true; }
    fi
  done
} > "$OUT/contact-points.yaml"
# Telegram chat id is written literally (Grafana turns "${VAR}" numbers into a number and then rejects it)
if flag TELEGRAM_ALERT_ENABLE false; then
  sed "s|@@TELEGRAM_CHAT_ID@@|$(getv TELEGRAM_CHAT_ID)|g" "$OUT/contact-points.yaml" > "$OUT/contact-points.yaml.tmp" && cat "$OUT/contact-points.yaml.tmp" > "$OUT/contact-points.yaml" && rm -f "$OUT/contact-points.yaml.tmp"
fi
# no channel enabled -> an empty list is not valid for every Grafana version; write a bare header instead
[ "${#enabled_names[@]}" -gt 0 ] || printf '# GENERATED by scripts/up.sh - no alert channel enabled\napiVersion: 1\n' > "$OUT/contact-points.yaml"

# alert message templates (always written; empty when ALERT_TEMPLATE_ENABLE=false)
if [ "$TPL_ON" -eq 1 ]; then
  { echo "# GENERATED by scripts/up.sh - do not edit (edit grafana/alerting/common/templates.yaml and .env instead)"; sed "s|@@ALERT_TIMEZONE@@|$ALERT_TZ|g" grafana/alerting/common/templates.yaml; } > "$OUT/templates.yaml"
else
  printf '# GENERATED by scripts/up.sh - ALERT_TEMPLATE_ENABLE is off\napiVersion: 1\n' > "$OUT/templates.yaml"
fi

timing="$(grep -E '^[[:space:]]+(group_by|group_wait|group_interval|repeat_interval):' grafana/alerting/common/policies.yaml)"
{
  echo "# GENERATED by scripts/up.sh - do not edit"
  echo "apiVersion: 1"
  echo "policies:"
  echo "  - orgId: 1"
  if [ "${#enabled_names[@]}" -eq 0 ]; then
    echo "    receiver: grafana-default-email"   # built-in Grafana receiver (nothing enabled)
    echo "$timing"
  else
    echo "    receiver: ${enabled_names[0]}"
    echo "$timing"
    if [ "${#enabled_names[@]}" -gt 1 ]; then
      echo "    routes:"
      for n in "${enabled_names[@]}"; do
        echo "      - receiver: $n"
        echo "        continue: true"
      done
    fi
  fi
} > "$OUT/policies.yaml"

# ---- optional feature: DTM app metrics (Spring Boot Actuator -> Prometheus) ----
# NOTE: files are rewritten in place (never delete+recreate the folders) because they are bind-mounted into containers
mkdir -p .generated/prometheus/scrape.d .generated/dashboards/app
rm -f .generated/prometheus/scrape.d/* .generated/dashboards/app/*
printf '# GENERATED by scripts/up.sh - APP_METRICS_ENABLE is off\napiVersion: 1\n' > "$OUT/rules-app.yaml"
if flag APP_METRICS_ENABLE false; then
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "@@APP_METRICS_AUTH@@" ]; then
      if [ -n "$APP_USER" ]; then printf '    basic_auth:\n      username: '"'"'%s'"'"'\n      password: '"'"'%s'"'"'\n' "$APP_USER" "$APP_PASS"; fi
    else
      printf '%s\n' "$line" | sed -e "s|@@APP_METRICS_TARGET@@|$APP_TARGET|g" -e "s|@@APP_METRICS_PATH@@|$APP_PATH|g" -e "s|@@APP_METRICS_SCHEME@@|$APP_SCHEME|g" -e "s|@@MONITORING_ENV@@|$M_ENV|g" -e "s|@@MONITORING_HOST@@|$M_HOST|g"
    fi
  done < features/app-metrics/scrape.yml > .generated/prometheus/scrape.d/app-metrics.yml
  cp features/app-metrics/dashboard.json .generated/dashboards/app/app-metrics.json
  cat features/app-metrics/rules.yaml > "$OUT/rules-app.yaml"
  echo "[ ON ] APP_METRICS_ENABLE -> $APP_SCHEME://$APP_TARGET$APP_PATH${APP_USER:+ (basic auth user $APP_USER)}"
else
  echo "[ off] APP_METRICS_ENABLE"
fi
printf '# GENERATED by scripts/up.sh - POSTGRES_ENABLE is off\napiVersion: 1\n' > "$OUT/rules-postgres.yaml"
if flag POSTGRES_ENABLE false; then
  sed -e "s|@@MONITORING_ENV@@|$M_ENV|g" -e "s|@@MONITORING_HOST@@|$M_HOST|g" features/postgres/scrape.yml > .generated/prometheus/scrape.d/postgres.yml
  cp features/postgres/dashboard.json .generated/dashboards/app/postgres.json
  cat features/postgres/rules.yaml > "$OUT/rules-postgres.yaml"
  echo "[ ON ] POSTGRES_ENABLE -> $PG_HOST:$PG_PORT/$PG_DB (user $PG_USER)"
else
  echo "[ off] POSTGRES_ENABLE"
fi
printf '# GENERATED by scripts/up.sh - UPTIME_ENABLE is off\napiVersion: 1\n' > "$OUT/rules-uptime.yaml"
if flag UPTIME_ENABLE false; then
  {
    echo "# GENERATED by scripts/up.sh - do not edit (edit UPTIME_URLS in .env)"
    echo "scrape_configs:"
    echo "  - job_name: uptime"
    echo "    metrics_path: /probe"
    echo "    params:"
    echo "      module: [http_2xx]"
    echo "    static_configs:"
    echo "      - targets:"
    for u in "${UP_URLS[@]}"; do echo "          - '$u'"; done
    echo "        labels:"
    echo "          env: '$M_ENV'"
    echo "    relabel_configs:"
    echo "      - source_labels: [__address__]"
    echo "        target_label: __param_target"
    echo "      - source_labels: [__param_target]"
    echo "        target_label: instance"
    echo "      - target_label: __address__"
    echo "        replacement: blackbox-exporter:9115"
  } > .generated/prometheus/scrape.d/uptime.yml
  cp features/uptime/dashboard.json .generated/dashboards/app/uptime.json
  cat features/uptime/rules.yaml > "$OUT/rules-uptime.yaml"
  echo "[ ON ] UPTIME_ENABLE -> ${#UP_URLS[@]} URL(s): ${UP_URLS[*]}"
else
  echo "[ off] UPTIME_ENABLE"
fi
new_prom="$(snap .generated/prometheus)"; new_graf="$(snap .generated/alerting .generated/dashboards)"

echo "[ OK ] generated .generated (alert channels: ${enabled_names[*]:-none})"
# exporter container is only part of the stack when POSTGRES_ENABLE=true; remove it when switched off
if ! flag POSTGRES_ENABLE false; then docker compose --profile postgres rm -sf postgres-exporter >/dev/null 2>&1 || true; fi
if ! flag UPTIME_ENABLE false; then docker compose --profile uptime rm -sf blackbox-exporter >/dev/null 2>&1 || true; fi
docker compose up -d "$@" || exit $?
if [ "$have_old" -eq 1 ]; then
  if [ "$old_prom" != "$new_prom" ]; then echo "[ .. ] Prometheus config changed -> restarting prometheus"; docker compose restart prometheus; fi
  if [ "$old_graf" != "$new_graf" ]; then echo "[ .. ] Grafana provisioning changed -> restarting grafana"; docker compose restart grafana; fi
fi
