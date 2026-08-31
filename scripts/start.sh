#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

load_env
require_command docker
require_absolute_path PERSONAL_AGENT_DATA_DIR
[[ -f "${PERSONAL_AGENT_DATA_DIR}/openclaw/openclaw.json" ]] || fail "Сначала выполните sudo ./scripts/prepare-host.sh."

compose config --quiet
log "Запуск закреплённого образа OpenClaw."
compose up -d openclaw-gateway
"${SCRIPT_DIR}/healthcheck.sh"
