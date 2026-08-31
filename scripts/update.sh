#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

load_env
require_command docker
require_value OPENCLAW_VERSION
image_ref="${OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION}}"

if [[ "${image_ref}" == *:latest ]]; then
  fail "OPENCLAW_IMAGE не должен использовать тег latest."
fi

log "Перед обновлением создаётся проверенный off-site backup."
"${SCRIPT_DIR}/backup.sh"
log "Загрузка вручную закреплённого образа ${image_ref}."
compose pull openclaw-gateway openclaw-cli
compose up -d openclaw-gateway
"${SCRIPT_DIR}/healthcheck.sh"
log "УСПЕХ: обновление завершено. Автоматический откат версии не выполнялся."
