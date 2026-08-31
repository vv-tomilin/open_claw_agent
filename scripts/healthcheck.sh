#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

load_env
require_command docker
require_absolute_path PERSONAL_AGENT_DATA_DIR
require_absolute_path PERSONAL_AGENT_BACKUP_DIR

log "Проверка Docker Compose."
compose config --quiet

for path in \
  "${PERSONAL_AGENT_DATA_DIR}/openclaw" \
  "${PERSONAL_AGENT_DATA_DIR}/workspace" \
  "${PERSONAL_AGENT_DATA_DIR}/auth-profile-secrets" \
  "${PERSONAL_AGENT_BACKUP_DIR}"; do
  [[ -d "${path}" && -r "${path}" ]] || fail "Каталог недоступен: ${path}"
done
[[ -f "${PERSONAL_AGENT_DATA_DIR}/openclaw/openclaw.json" ]] || fail "Не найден openclaw.json."

container_id="$(compose ps -q openclaw-gateway)"
[[ -n "${container_id}" ]] || fail "Контейнер openclaw-gateway не создан."
[[ "$(docker inspect --format '{{.State.Running}}' "${container_id}")" == true ]] || fail "Контейнер не запущен."

health_timeout="${HEALTHCHECK_TIMEOUT_SECONDS:-120}"
[[ "${health_timeout}" =~ ^[0-9]+$ ]] || fail "HEALTHCHECK_TIMEOUT_SECONDS должен быть числом."
deadline=$((SECONDS + health_timeout))
while true; do
  health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container_id}")"
  if [[ "${health_status}" == healthy ]]; then
    break
  fi
  if [[ "${health_status}" == unhealthy || "${health_status}" == none || "${SECONDS}" -ge "${deadline}" ]]; then
    fail "Docker healthcheck: ${health_status}."
  fi
  sleep 2
done

gateway_host="${OPENCLAW_GATEWAY_HOST:-127.0.0.1}"
gateway_port="${OPENCLAW_GATEWAY_PORT:-18789}"
if command -v curl >/dev/null 2>&1; then
  curl -fsS --max-time 5 "http://${gateway_host}:${gateway_port}/healthz" >/dev/null || fail "Endpoint /healthz не отвечает."
fi

require_restic_env
restic snapshots --latest 1 >/dev/null
log "УСПЕХ: контейнер, постоянное состояние, проверка OpenClaw и restic доступны."
