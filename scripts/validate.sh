#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

failed=0

if grep -Eq 'OPENCLAW_(IMAGE|VERSION)=.*latest' "${PROJECT_DIR}/.env.example"; then
  printf 'ОШИБКА: в .env.example обнаружен latest.\n' >&2
  failed=1
else
  printf 'УСПЕХ: версия OpenClaw закреплена.\n'
fi

for required in compose.yaml .env.example .gitignore README.md config/openclaw.json scripts/setup.sh scripts/enable-agent-access.sh; do
  if [[ ! -f "${PROJECT_DIR}/${required}" ]]; then
    printf 'ОШИБКА: отсутствует %s.\n' "${required}" >&2
    failed=1
  fi
done

if ! grep -Eq '^[[:space:]]*profile:[[:space:]]*"full"' "${PROJECT_DIR}/config/openclaw.json"; then
  printf 'ОШИБКА: шаблон OpenClaw не использует полный профиль инструментов.\n' >&2
  failed=1
elif grep -Eq '^[[:space:]]*(alsoAllow|deny|workspaceOnly):' "${PROJECT_DIR}/config/openclaw.json"; then
  printf 'ОШИБКА: в полном профиле обнаружено конфликтующее ограничение инструментов.\n' >&2
  failed=1
else
  printf 'УСПЕХ: полный профиль инструментов включён без глобальных ограничений.\n'
fi

if grep -Eq '^[[:space:]]*env_file:' "${PROJECT_DIR}/compose.yaml"; then
  printf 'ОШИБКА: compose.yaml передаёт контейнеру весь .env через env_file.\n' >&2
  failed=1
elif grep -Eq '^[[:space:]]*(RESTIC_PASSWORD_FILE|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|B2_ACCOUNT_ID|B2_ACCOUNT_KEY|RESTIC_REST_USERNAME|RESTIC_REST_PASSWORD):' "${PROJECT_DIR}/compose.yaml"; then
  printf 'ОШИБКА: в окружение OpenClaw передаются host-only секреты резервного копирования.\n' >&2
  failed=1
else
  printf 'УСПЕХ: контейнер получает только явно перечисленные переменные OpenClaw.\n'
fi

if command -v node >/dev/null 2>&1; then
  node "${PROJECT_DIR}/scripts/validate-config.mjs"
else
  printf 'ПРОПУСК: Node.js не установлен; базовая проверка JSON5 не выполнена.\n'
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose --project-directory "${PROJECT_DIR}" \
    --env-file "${PROJECT_DIR}/.env.example" config --quiet
  printf 'УСПЕХ: docker compose config.\n'
else
  printf 'ПРОПУСК: Docker Compose не установлен.\n'
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${PROJECT_DIR}"/scripts/*.sh
  printf 'УСПЕХ: shellcheck.\n'
else
  printf 'ПРОПУСК: shellcheck не установлен.\n'
fi

if git -C "${PROJECT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "${PROJECT_DIR}" diff --check
  git -C "${PROJECT_DIR}" diff --cached --check
  printf 'УСПЕХ: git diff --check.\n'
else
  printf 'ПРОПУСК: каталог ещё не инициализирован как Git repository.\n'
fi

[[ "${failed}" -eq 0 ]] || exit 1
printf 'УСПЕХ: безопасная локальная валидация завершена.\n'
