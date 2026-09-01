#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Использование:
  ./scripts/setup.sh new
  ./scripts/setup.sh restore [latest|SNAPSHOT_ID] [--force]

new      Подготовить host, создать новый restic repository, загрузить image и запустить OpenClaw.
restore  Подготовить host, проверить существующий restic repository и восстановить состояние.
         Gateway после восстановления не запускается автоматически.
EOF
}

mode="${1:-}"
case "${mode}" in
  new|restore) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 1 ;;
esac

load_env
require_command docker
require_command restic
require_command jq
require_absolute_path PERSONAL_AGENT_DATA_DIR
require_absolute_path PERSONAL_AGENT_BACKUP_DIR
require_absolute_path RESTIC_PASSWORD_FILE

openclaw_uid="${OPENCLAW_UID:-1000}"
[[ "${openclaw_uid}" =~ ^[0-9]+$ ]] || fail "OPENCLAW_UID должен быть числом."
if [[ "$(id -u)" -ne 0 && "$(id -u)" -ne "${openclaw_uid}" ]]; then
  fail "Текущий UID $(id -u) не совпадает с OPENCLAW_UID=${openclaw_uid}. Используйте deployment-пользователя с этим UID или запустите setup.sh через sudo."
fi

secrets_dir="$(dirname -- "${RESTIC_PASSWORD_FILE}")"
require_safe_managed_directory "${secrets_dir}" "каталога секретов restic"

can_prepare_without_root=1
for target in "${PERSONAL_AGENT_DATA_DIR}" "${PERSONAL_AGENT_BACKUP_DIR}" "${secrets_dir}"; do
  candidate="${target}"
  while [[ ! -e "${candidate}" && "${candidate}" != "/" ]]; do
    candidate="$(dirname -- "${candidate}")"
  done
  if [[ ! -d "${candidate}" || ! -w "${candidate}" ]]; then
    can_prepare_without_root=0
  fi
done

prepare_arguments=()
if [[ "${mode}" == restore ]]; then
  prepare_arguments+=(--prompt-restic-password)
fi

if [[ "$(id -u)" -eq 0 || "${can_prepare_without_root}" -eq 1 ]]; then
  "${SCRIPT_DIR}/prepare-host.sh" "${prepare_arguments[@]}"
else
  require_command sudo
  log "Для однократного создания host-каталогов требуется sudo. Повседневные операции останутся у deployment-пользователя."
  sudo -- "${SCRIPT_DIR}/prepare-host.sh" "${prepare_arguments[@]}"
fi

require_restic_env
compose config --quiet

case "${mode}" in
  new)
    [[ "$#" -eq 1 ]] || fail "Для режима new дополнительные параметры не поддерживаются."
    if restic cat config >/dev/null 2>&1; then
      snapshot_count="$(restic snapshots --json --tag personal-agent | jq 'length')"
      [[ "${snapshot_count}" -eq 0 ]] || fail "В repository уже есть snapshots personal-agent. Для переноса используйте setup.sh restore latest."
      log "Найден уже инициализированный repository без snapshots personal-agent; продолжаем прерванный setup."
    else
      log "Инициализация нового зашифрованного restic repository."
      restic init
    fi
    log "Загрузка закреплённого image OpenClaw."
    compose pull openclaw-gateway openclaw-cli
    "${SCRIPT_DIR}/start.sh"
    log "УСПЕХ: новый экземпляр запущен. Следующий шаг — Telegram pairing по README."
    ;;
  restore)
    snapshot="${2:-latest}"
    force_argument="${3:-}"
    [[ "$#" -le 3 ]] || fail "Слишком много параметров для режима restore."
    [[ -z "${force_argument}" || "${force_argument}" == "--force" ]] || fail "Третий параметр может быть только --force."
    log "Проверка доступа к существующему restic repository."
    snapshot_count="$(restic snapshots --json --tag personal-agent | jq 'length')"
    [[ "${snapshot_count}" -gt 0 ]] || fail "В repository не найдено snapshots с тегом personal-agent."
    log "Загрузка закреплённого image OpenClaw для проверки архива."
    compose pull openclaw-gateway openclaw-cli
    if [[ -n "${force_argument}" ]]; then
      "${SCRIPT_DIR}/restore.sh" "${snapshot}" "${force_argument}"
    else
      "${SCRIPT_DIR}/restore.sh" "${snapshot}"
    fi
    log "УСПЕХ: состояние восстановлено, но Gateway не запущен."
    log "Убедитесь, что старый экземпляр выключен, затем выполните ./scripts/start.sh"
    ;;
esac
