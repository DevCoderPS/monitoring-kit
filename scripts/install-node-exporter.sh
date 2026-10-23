#!/usr/bin/env bash
# Installs node_exporter (CPU / RAM / Disk / Network metrics) as a systemd service on Linux.
#
# Usage:   sudo bash scripts/install-node-exporter.sh
# Options (environment variables):
#   NODE_EXPORTER_VERSION   default 1.9.1
#   LISTEN_ADDRESS          default = the Docker bridge gateway IP (usually 172.17.0.1)
#
# Why the Docker bridge IP?  The Prometheus container reaches the host through
# "host.docker.internal" (= that gateway IP, see compose.yaml extra_hosts).
# Listening ONLY on that address means containers on this host can scrape it,
# but the exporter is NOT exposed on your public/LAN network interfaces.
set -euo pipefail

VERSION="${NODE_EXPORTER_VERSION:-1.9.1}"

if [ "$(id -u)" -ne 0 ]; then echo "Please run with sudo:  sudo bash $0" >&2; exit 1; fi
for c in curl tar sha256sum systemctl; do
  command -v "$c" >/dev/null 2>&1 || { echo "Missing required command: $c" >&2; exit 1; }
done

case "$(uname -m)" in
  x86_64)        ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported CPU architecture: $(uname -m)" >&2; exit 1 ;;
esac

if systemctl list-unit-files 2>/dev/null | grep -q '^node_exporter\.service'; then
  echo "A node_exporter service already exists on this machine:"
  systemctl status node_exporter --no-pager || true
  echo "Not touching it. Review it manually (it must listen where the Prometheus container can reach it)."
  exit 0
fi

# ---- decide the listen address ----
if [ -z "${LISTEN_ADDRESS:-}" ]; then
  if command -v docker >/dev/null 2>&1; then
    LISTEN_ADDRESS="$(docker network inspect bridge -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)"
  fi
  LISTEN_ADDRESS="${LISTEN_ADDRESS:-172.17.0.1}"
fi
echo "node_exporter will listen on ${LISTEN_ADDRESS}:9100"

# ---- download + verify checksum ----
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
TAR="node_exporter-${VERSION}.linux-${ARCH}.tar.gz"
BASE="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}"
echo "Downloading ${TAR} ..."
curl -fsSL "${BASE}/${TAR}" -o "${WORK}/${TAR}"
curl -fsSL "${BASE}/sha256sums.txt" -o "${WORK}/sha256sums.txt"
( cd "$WORK" && grep " ${TAR}\$" sha256sums.txt | sha256sum --check --strict )
tar -xzf "${WORK}/${TAR}" -C "$WORK"

# ---- install ----
id node_exporter >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter
install -m 0755 "${WORK}/node_exporter-${VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/node_exporter
printf 'NODE_EXPORTER_LISTEN_ADDRESS=%s:9100\n' "$LISTEN_ADDRESS" > /etc/default/node_exporter

cat > /etc/systemd/system/node_exporter.service <<UNIT
[Unit]
Description=Prometheus node_exporter (host metrics)
After=network-online.target docker.service
Wants=network-online.target

[Service]
User=node_exporter
Group=node_exporter
EnvironmentFile=/etc/default/node_exporter
ExecStart=/usr/local/bin/node_exporter --web.listen-address=\${NODE_EXPORTER_LISTEN_ADDRESS}
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now node_exporter
sleep 2
systemctl --no-pager --lines=3 status node_exporter || true

if curl -fsS "http://${LISTEN_ADDRESS}:9100/metrics" | head -n 3; then
  echo
  echo "OK: node_exporter answers on http://${LISTEN_ADDRESS}:9100/metrics"
else
  echo "node_exporter did not answer yet. Check:  journalctl -u node_exporter -n 30" >&2
fi
cat <<MSG

Next steps:
  1) In .env set  PLATFORM=linux  (and edit env/host labels in prometheus/prometheus.linux.yml)
  2) docker compose up -d
  3) If the Prometheus target shows DOWN, a host firewall is probably blocking containers from
     reaching ${LISTEN_ADDRESS}:9100. Example for ufw (allow only Docker's private ranges):
       sudo ufw allow from 172.16.0.0/12 to ${LISTEN_ADDRESS} port 9100 proto tcp
MSG
