#!/usr/bin/env bash
# Stop and remove all monitoring containers (including optional ones). Data volumes are kept.
#   Usage: bash scripts/down.sh        (add -v at the end to ALSO delete the stored data)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
docker compose --profile '*' down "$@"
