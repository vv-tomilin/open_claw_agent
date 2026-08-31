#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

load_env
require_command docker
require_command find
require_absolute_path PERSONAL_AGENT_DATA_DIR
require_absolute_path PERSONAL_AGENT_BACKUP_DIR
require_restic_env

[[ -d "${PERSONAL_AGENT_DATA_DIR}/openclaw" ]] || fail "Состояние OpenClaw не найдено."
mkdir -p "${PERSONAL_AGENT_BACKUP_DIR}"
chmod 0700 "${PERSONAL_AGENT_BACKUP_DIR}"
stage_dir="$(mktemp -d "${PERSONAL_AGENT_BACKUP_DIR}/.backup.XXXXXX")"
stage_name="$(basename "${stage_dir}")"
cleanup() { rm -rf -- "${stage_dir}"; }
trap cleanup EXIT
chmod 0700 "${stage_dir}"
ensure_openclaw_owner "${stage_dir}"

log "Создание консистентного архива штатной командой OpenClaw."
compose run -T --rm --no-deps --entrypoint node openclaw-gateway \
  dist/index.js backup create --output "/backup/${stage_name}" --verify

archive="$(find "${stage_dir}" -maxdepth 1 -type f -name '*openclaw-backup.tar.gz' -print -quit)"
[[ -n "${archive}" ]] || fail "OpenClaw не создал ожидаемый архив."

if [[ -d "${PERSONAL_AGENT_DATA_DIR}/auth-profile-secrets" ]]; then
  cp -a "${PERSONAL_AGENT_DATA_DIR}/auth-profile-secrets" "${stage_dir}/auth-profile-secrets"
fi

log "Передача проверенного bundle в зашифрованный restic repository."
(
  cd "${stage_dir}"
  restic backup --tag personal-agent .
)
restic snapshots --latest 1 --tag personal-agent >/dev/null
log "УСПЕХ: резервная копия создана, проверена OpenClaw и сохранена в restic."
