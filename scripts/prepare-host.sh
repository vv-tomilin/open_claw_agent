#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

[[ "$(id -u)" -eq 0 ]] || fail "Запустите prepare-host.sh через sudo."
load_env
require_command docker
require_command restic
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin недоступен."

require_absolute_path PERSONAL_AGENT_DATA_DIR
require_absolute_path PERSONAL_AGENT_BACKUP_DIR
require_value OPENCLAW_VERSION
require_value OPENCLAW_GATEWAY_TOKEN
require_value OPENROUTER_API_KEY
require_value TELEGRAM_BOT_TOKEN
require_value PRIMARY_MODEL
require_value UTILITY_MODEL
require_value HEAVY_MODEL
if [[ "${OPENCLAW_VERSION}" == latest ]]; then
  fail "OPENCLAW_VERSION не должен быть latest."
fi

uid="${OPENCLAW_UID:-1000}"
gid="${OPENCLAW_GID:-1000}"
[[ "${uid}" =~ ^[0-9]+$ ]] || fail "OPENCLAW_UID должен быть числом."
[[ "${gid}" =~ ^[0-9]+$ ]] || fail "OPENCLAW_GID должен быть числом."

log "Создание persistent-каталогов."
install -d -m 0750 -o "${uid}" -g "${gid}" \
  "${PERSONAL_AGENT_DATA_DIR}/openclaw" \
  "${PERSONAL_AGENT_DATA_DIR}/workspace" \
  "${PERSONAL_AGENT_DATA_DIR}/auth-profile-secrets" \
  "${PERSONAL_AGENT_BACKUP_DIR}"

config_target="${PERSONAL_AGENT_DATA_DIR}/openclaw/openclaw.json"
if [[ ! -e "${config_target}" ]]; then
  install -m 0640 -o "${uid}" -g "${gid}" "${PROJECT_DIR}/config/openclaw.json" "${config_target}"
  log "Установлен начальный openclaw.json. Дальнейшие runtime-изменения остаются в persistent state."
else
  log "Существующий openclaw.json сохранён без изменений."
fi

chmod 0750 "${PERSONAL_AGENT_DATA_DIR}" "${PERSONAL_AGENT_BACKUP_DIR}"
chown -R "${uid}:${gid}" "${PERSONAL_AGENT_DATA_DIR}" "${PERSONAL_AGENT_BACKUP_DIR}"

if [[ -f "${RESTIC_PASSWORD_FILE:-}" ]]; then
  chown "${uid}:${gid}" "${RESTIC_PASSWORD_FILE}"
  chmod 0600 "${RESTIC_PASSWORD_FILE}"
fi
chmod 0600 "${ENV_FILE}"

log "Проверка синтаксиса Docker Compose."
compose config --quiet
log "Сервер подготовлен. Контейнеры не запускались."
