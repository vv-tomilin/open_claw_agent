#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

prompt_restic_password=0
case "${1:-}" in
  "") ;;
  --prompt-restic-password) prompt_restic_password=1 ;;
  -h|--help)
    printf 'Использование: %s [--prompt-restic-password]\n' "$0"
    exit 0
    ;;
  *) fail "Неизвестный параметр: ${1}" ;;
esac

load_env
require_command docker
require_command restic
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin недоступен."

require_absolute_path PERSONAL_AGENT_DATA_DIR
require_absolute_path PERSONAL_AGENT_BACKUP_DIR
require_absolute_path RESTIC_PASSWORD_FILE
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

is_root=0
if [[ "$(id -u)" -eq 0 ]]; then
  is_root=1
elif [[ "$(id -u)" -ne "${uid}" ]]; then
  fail "Для работы без sudo текущий UID должен совпадать с OPENCLAW_UID=${uid}. Текущий UID: $(id -u)."
fi

secrets_dir="$(dirname -- "${RESTIC_PASSWORD_FILE}")"
require_safe_managed_directory "${secrets_dir}" "каталога секретов restic"

log "Создание persistent-каталогов."
managed_directories=(
  "${PERSONAL_AGENT_DATA_DIR}/openclaw"
  "${PERSONAL_AGENT_DATA_DIR}/workspace"
  "${PERSONAL_AGENT_DATA_DIR}/auth-profile-secrets"
  "${PERSONAL_AGENT_BACKUP_DIR}"
)

if [[ "${is_root}" -eq 1 ]]; then
  install -d -m 0750 -o "${uid}" -g "${gid}" "${managed_directories[@]}"
  install -d -m 0700 -o "${uid}" -g "${gid}" "${secrets_dir}"
else
  install -d -m 0750 "${managed_directories[@]}"
  install -d -m 0700 "${secrets_dir}"
fi

config_target="${PERSONAL_AGENT_DATA_DIR}/openclaw/openclaw.json"
if [[ ! -e "${config_target}" ]]; then
  if [[ "${is_root}" -eq 1 ]]; then
    install -m 0640 -o "${uid}" -g "${gid}" "${PROJECT_DIR}/config/openclaw.json" "${config_target}"
  else
    install -m 0640 "${PROJECT_DIR}/config/openclaw.json" "${config_target}"
  fi
  log "Установлен начальный openclaw.json. Дальнейшие runtime-изменения остаются в persistent state."
else
  log "Существующий openclaw.json сохранён без изменений."
fi

chmod 0750 "${PERSONAL_AGENT_DATA_DIR}" "${PERSONAL_AGENT_BACKUP_DIR}"
chmod 0700 "${secrets_dir}"
if [[ "${is_root}" -eq 1 ]]; then
  chown -R "${uid}:${gid}" "${PERSONAL_AGENT_DATA_DIR}" "${PERSONAL_AGENT_BACKUP_DIR}"
  chown "${uid}:${gid}" "${secrets_dir}"
fi

if [[ -e "${RESTIC_PASSWORD_FILE}" && ! -f "${RESTIC_PASSWORD_FILE}" ]]; then
  fail "RESTIC_PASSWORD_FILE существует, но не является обычным файлом: ${RESTIC_PASSWORD_FILE}"
fi

if [[ ! -f "${RESTIC_PASSWORD_FILE}" || "${prompt_restic_password}" -eq 1 ]]; then
  [[ -t 0 ]] || fail "Файл пароля restic отсутствует. Запустите prepare-host.sh в интерактивном терминале."
  printf 'Введите master password restic (для восстановления — существующий пароль): ' >&2
  read -r -s restic_password
  printf '\nПовторите master password restic: ' >&2
  read -r -s restic_password_confirm
  printf '\n' >&2
  [[ -n "${restic_password}" ]] || fail "Пароль restic не может быть пустым."
  [[ "${restic_password}" == "${restic_password_confirm}" ]] || fail "Введённые пароли restic не совпадают."
  umask 077
  printf '%s\n' "${restic_password}" >"${RESTIC_PASSWORD_FILE}"
  unset restic_password restic_password_confirm
  log "Защищённый файл пароля restic записан. Сохраните его копию в password manager."
fi

if [[ "${is_root}" -eq 1 ]]; then
  chown "${uid}:${gid}" "${RESTIC_PASSWORD_FILE}"
fi
chmod 0600 "${RESTIC_PASSWORD_FILE}"
chmod 0600 "${ENV_FILE}"

log "Проверка синтаксиса Docker Compose."
compose config --quiet
log "Сервер подготовлен. Контейнеры не запускались."
