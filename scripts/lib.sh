#!/usr/bin/env bash

# Общие безопасные функции инфраструктурных скриптов.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PROJECT_DIR}/.env"

log() {
  printf '[personal-agent] %s\n' "$*"
}

fail() {
  printf '[personal-agent] ОШИБКА: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Не найдена команда: $1"
}

load_env() {
  [[ -f "${ENV_FILE}" ]] || fail "Файл .env не найден. Скопируйте .env.example в .env и заполните его."
  set -a
  # shellcheck disable=SC1090
  . "${ENV_FILE}"
  set +a
}

require_value() {
  local name="$1"
  local value="${!name:-}"
  [[ -n "${value}" ]] || fail "Переменная ${name} не задана."
  [[ "${value}" != PLACEHOLDER* ]] || fail "Переменная ${name} всё ещё содержит значение-заглушку."
}

require_absolute_path() {
  local name="$1"
  local value="${!name:-}"
  [[ "${value}" == /* ]] || fail "Переменная ${name} должна содержать абсолютный POSIX-путь."
  [[ "${value}" != "/" ]] || fail "Корневой каталог / нельзя использовать как ${name}."
}

require_safe_managed_directory() {
  local path="$1"
  local label="$2"

  [[ "${path}" == /* ]] || fail "${label} должен быть абсолютным POSIX-путём."
  case "${path%/}" in
    ""|/|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
      fail "Небезопасный слишком широкий путь для ${label}: ${path}"
      ;;
  esac
}

compose() {
  docker compose --project-directory "${PROJECT_DIR}" --env-file "${ENV_FILE}" "$@"
}

require_restic_env() {
  require_command restic
  require_value RESTIC_REPOSITORY
  require_value RESTIC_PASSWORD_FILE
  [[ -f "${RESTIC_PASSWORD_FILE}" ]] || fail "Файл пароля restic не найден: ${RESTIC_PASSWORD_FILE}"
  [[ -r "${RESTIC_PASSWORD_FILE}" ]] || fail "Файл пароля restic недоступен текущему пользователю: ${RESTIC_PASSWORD_FILE}"
}

ensure_openclaw_owner() {
  local path="$1"
  local openclaw_uid="${OPENCLAW_UID:-1000}"
  local openclaw_gid="${OPENCLAW_GID:-1000}"

  [[ "${openclaw_uid}" =~ ^[0-9]+$ ]] || fail "OPENCLAW_UID должен быть числом."
  [[ "${openclaw_gid}" =~ ^[0-9]+$ ]] || fail "OPENCLAW_GID должен быть числом."

  if [[ "$(id -u)" -eq 0 ]]; then
    chown -R "${openclaw_uid}:${openclaw_gid}" "${path}"
  elif [[ "$(id -u)" -ne "${openclaw_uid}" ]]; then
    fail "Каталог ${path} должен принадлежать UID ${openclaw_uid}; запустите prepare-host.sh с sudo."
  fi
}
