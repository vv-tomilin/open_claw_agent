#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

load_env
require_command docker
require_command jq
require_absolute_path PERSONAL_AGENT_DATA_DIR

config_path="${PERSONAL_AGENT_DATA_DIR}/openclaw/openclaw.json"
[[ -f "${config_path}" ]] || fail "Не найден ${config_path}. Сначала выполните setup.sh new или setup.sh restore."

run_openclaw_config() {
  compose run -T --rm --no-deps --entrypoint node openclaw-gateway \
    dist/index.js config "$@"
}

patch='{
  tools: {
    profile: "full",
    alsoAllow: null,
    fs: null,
    deny: null,
  },
}'

policy_is_full() {
  jq -e '
  .profile == "full" and
  (has("alsoAllow") | not) and
  (has("fs") | not) and
  (has("deny") | not)
  ' <<<"$1" >/dev/null
}

tools_json="$(run_openclaw_config get tools --json)"
if policy_is_full "${tools_json}"; then
  log "Полный профиль уже включён; persistent-конфигурация не изменяется."
else
  log "Проверка миграции полного доступа без изменения persistent state."
  printf '%s\n' "${patch}" | run_openclaw_config patch --stdin --dry-run

  log "Включение полного профиля инструментов в persistent-конфигурации."
  printf '%s\n' "${patch}" | run_openclaw_config patch --stdin
fi

run_openclaw_config validate
tools_json="$(run_openclaw_config get tools --json)"
policy_is_full "${tools_json}" || fail "Итоговая политика tools не соответствует полному профилю."

if [[ -n "$(compose ps --status running -q openclaw-gateway 2>/dev/null)" ]]; then
  log "Пересоздание Gateway для применения политики и нового allowlist окружения."
  compose up -d --force-recreate openclaw-gateway
  "${SCRIPT_DIR}/healthcheck.sh"
else
  log "Gateway остановлен; новая политика будет применена при следующем запуске."
fi

log "УСПЕХ: полный доступ агента включён. Повторный запуск команды безопасен."
