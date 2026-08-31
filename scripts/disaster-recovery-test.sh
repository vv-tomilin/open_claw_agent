#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

load_env
require_command docker
require_command find
require_command jq
require_command tar
require_absolute_path PERSONAL_AGENT_BACKUP_DIR
require_restic_env

mkdir -p "${PERSONAL_AGENT_BACKUP_DIR}"
test_dir="$(mktemp -d "${PERSONAL_AGENT_BACKUP_DIR}/.dr-test.XXXXXX")"
cleanup() { rm -rf -- "${test_dir}"; }
trap cleanup EXIT
chmod 0700 "${test_dir}"

log "Восстановление latest snapshot только во временный каталог."
restic restore latest --tag personal-agent --target "${test_dir}/restic"
archive="$(find "${test_dir}/restic" -type f -name '*openclaw-backup.tar.gz' -print -quit)"
[[ -n "${archive}" ]] || fail "В backup отсутствует архив OpenClaw."
relative_archive="${archive#${PERSONAL_AGENT_BACKUP_DIR}/}"

ensure_openclaw_owner "${test_dir}"
compose run -T --rm --no-deps --entrypoint node openclaw-gateway \
  dist/index.js backup verify "/backup/${relative_archive}"

mkdir -p "${test_dir}/extracted"
tar --extract --gzip --file "${archive}" --directory "${test_dir}/extracted" \
  --no-same-owner --no-same-permissions

state_source="$(find "${test_dir}/extracted" -type d -path '*/payload/posix/home/node/.openclaw' -print -quit)"
[[ -n "${state_source}" ]] || fail "После restore отсутствует state asset."
manifest="$(find "${test_dir}/extracted" -type f -name manifest.json -print -quit)"
[[ -n "${manifest}" ]] || fail "Не найден manifest.json."
jq -e '.assets[] | select(.kind == "state" and .sourcePath == "/home/node/.openclaw")' \
  "${manifest}" >/dev/null || fail "Manifest не содержит ожидаемое сопоставление state asset."

if command -v sqlite3 >/dev/null 2>&1; then
  while IFS= read -r database; do
    [[ "$(sqlite3 "${database}" 'PRAGMA integrity_check;')" == ok ]] || fail "SQLite integrity check не пройден: ${database}"
  done < <(find "${test_dir}/extracted" -type f \( -name '*.sqlite' -o -name '*.db' \) -print)
else
  log "sqlite3 не установлен; проверка SQLite уже выполнена штатным openclaw backup verify."
fi

log "УСПЕХ: тест аварийного восстановления завершён без запуска Gateway, Telegram и заданий агента."
