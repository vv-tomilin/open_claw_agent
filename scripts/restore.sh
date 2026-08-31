#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

snapshot="latest"
force=0
for argument in "$@"; do
  case "${argument}" in
    --force) force=1 ;;
    latest) snapshot=latest ;;
    -h|--help)
      printf 'Использование: %s [latest|SNAPSHOT_ID] [--force]\n' "$0"
      exit 0
      ;;
    -*) fail "Неизвестный параметр: ${argument}" ;;
    *) snapshot="${argument}" ;;
  esac
done

load_env
require_command docker
require_command find
require_command jq
require_command tar
require_absolute_path PERSONAL_AGENT_DATA_DIR
require_absolute_path PERSONAL_AGENT_BACKUP_DIR
require_restic_env

if [[ -n "$(compose ps --status running -q openclaw-gateway 2>/dev/null)" ]]; then
  fail "Gateway запущен. Остановите его командой ./scripts/stop.sh перед восстановлением."
fi

state_dir="${PERSONAL_AGENT_DATA_DIR}/openclaw"
workspace_dir="${PERSONAL_AGENT_DATA_DIR}/workspace"
auth_dir="${PERSONAL_AGENT_DATA_DIR}/auth-profile-secrets"

meaningful_state=0
if [[ -d "${state_dir}" ]]; then
  if find "${state_dir}" -mindepth 1 -maxdepth 1 ! -name openclaw.json -print -quit | grep -q .; then
    meaningful_state=1
  elif [[ -f "${state_dir}/openclaw.json" ]] && ! cmp -s "${state_dir}/openclaw.json" "${PROJECT_DIR}/config/openclaw.json"; then
    meaningful_state=1
  fi
fi
for directory in "${workspace_dir}" "${auth_dir}"; do
  if [[ -d "${directory}" ]] && find "${directory}" -mindepth 1 -print -quit | grep -q .; then
    meaningful_state=1
  fi
done

if [[ "${meaningful_state}" -eq 1 && "${force}" -ne 1 ]]; then
  fail "Обнаружено существующее состояние. Повторите с --force только после проверки backup и остановки старого экземпляра."
fi

mkdir -p "${PERSONAL_AGENT_BACKUP_DIR}"
work_dir="$(mktemp -d "${PERSONAL_AGENT_BACKUP_DIR}/.restore.XXXXXX")"
rollback_dir=""
cleanup() {
  local status=$?
  rm -rf -- "${work_dir}"
  if [[ "${status}" -ne 0 && -n "${rollback_dir}" && -d "${rollback_dir}" ]]; then
    printf '[personal-agent] Предыдущее состояние сохранено для ручного отката: %s\n' "${rollback_dir}" >&2
  fi
}
trap cleanup EXIT
chmod 0700 "${work_dir}"

log "Получение snapshot ${snapshot} из restic во временный каталог."
restic restore "${snapshot}" --tag personal-agent --target "${work_dir}/restic"

archive="$(find "${work_dir}/restic" -type f -name '*openclaw-backup.tar.gz' -print -quit)"
[[ -n "${archive}" ]] || fail "В snapshot не найден штатный архив OpenClaw."
relative_archive="${archive#${PERSONAL_AGENT_BACKUP_DIR}/}"

# Контейнер OpenClaw работает как непривилегированный пользователь и должен
# прочитать архив внутри смонтированного backup-каталога.
ensure_openclaw_owner "${work_dir}"
log "Проверка архива штатной командой OpenClaw без изменения live state."
compose run -T --rm --no-deps --entrypoint node openclaw-gateway \
  dist/index.js backup verify "/backup/${relative_archive}"

# В закреплённой стабильной версии v2026.7.1-2 нет команды whole-archive restore.
# Официальный механизм: verify, распаковка в новый staging и активация по manifest.
mkdir -p "${work_dir}/extracted"
tar --extract --gzip --file "${archive}" --directory "${work_dir}/extracted" \
  --no-same-owner --no-same-permissions

manifest="$(find "${work_dir}/extracted" -type f -name manifest.json -print -quit)"
[[ -n "${manifest}" ]] || fail "В проверенном архиве не найден manifest.json."
jq -e '.assets[] | select(.kind == "state" and .sourcePath == "/home/node/.openclaw")' \
  "${manifest}" >/dev/null || fail "Manifest не содержит ожидаемое сопоставление state asset."

state_source="$(find "${work_dir}/extracted" -type d -path '*/payload/posix/home/node/.openclaw' -print -quit)"
[[ -n "${state_source}" ]] || fail "В проверенном архиве не найден state asset /home/node/.openclaw."

auth_source="$(find "${work_dir}/restic" -type d -name auth-profile-secrets -print -quit)"
rollback_dir="${PERSONAL_AGENT_BACKUP_DIR}/pre-restore-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir "${rollback_dir}"

for directory in "${state_dir}" "${workspace_dir}" "${auth_dir}"; do
  if [[ -e "${directory}" ]]; then
    mv -- "${directory}" "${rollback_dir}/$(basename "${directory}")"
  fi
done

mkdir -p "${state_dir}" "${workspace_dir}" "${auth_dir}"
cp -a "${state_source}/." "${state_dir}/"

# Workspace является отдельным bind mount. Переносим его из восстановленного
# state asset в самостоятельный каталог host-машины.
if [[ -d "${state_dir}/workspace" ]]; then
  cp -a "${state_dir}/workspace/." "${workspace_dir}/"
  rm -rf -- "${state_dir}/workspace"
fi
mkdir -p "${state_dir}/workspace"

if [[ -n "${auth_source}" ]]; then
  cp -a "${auth_source}/." "${auth_dir}/"
fi

ensure_openclaw_owner "${state_dir}"
ensure_openclaw_owner "${workspace_dir}"
ensure_openclaw_owner "${auth_dir}"
chmod 0750 "${state_dir}" "${workspace_dir}" "${auth_dir}"

log "Безопасная offline-проверка восстановленной конфигурации."
compose run -T --rm --no-deps --entrypoint node openclaw-gateway \
  dist/index.js doctor --json
log "УСПЕХ: состояние восстановлено. Gateway НЕ запущен. Предыдущее состояние сохранено: ${rollback_dir}"
log "Перед запуском убедитесь, что старый Telegram/OpenClaw экземпляр отключён."
