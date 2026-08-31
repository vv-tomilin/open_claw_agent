#!/usr/bin/env bash
set -Eeuo pipefail

# Устанавливает базовые зависимости на будущий Debian/Ubuntu x86_64.
# Скрипт не запускает OpenClaw и не создаёт секреты.

log() { printf '[bootstrap] %s\n' "$*"; }
fail() { printf '[bootstrap] ОШИБКА: %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail "Запустите скрипт через sudo или от root."
[[ -r /etc/os-release ]] || fail "Не найден /etc/os-release."

# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
  debian|ubuntu) ;;
  *) fail "Поддерживаются только Debian и Ubuntu, обнаружено: ${ID:-неизвестно}." ;;
esac

case "$(dpkg --print-architecture)" in
  amd64) ;;
  *) fail "Поддерживается только x86_64/amd64." ;;
esac

export DEBIAN_FRONTEND=noninteractive
log "Обновление индекса пакетов и установка базовых утилит."
apt-get update
apt-get install -y ca-certificates curl gnupg jq make restic

docker_present=0
if command -v docker >/dev/null 2>&1; then
  docker_present=1
fi

if [[ "${docker_present}" -eq 1 ]] && docker compose version >/dev/null 2>&1; then
  log "Docker Engine и Compose plugin уже доступны; переустановка не требуется."
else
  log "Подключение официального репозитория Docker."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${ID}
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  apt-get update
  if [[ "${docker_present}" -eq 1 ]]; then
    log "Существующий Docker Engine сохранён; устанавливается только Compose plugin."
    apt-get install -y docker-compose-plugin
  else
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
  fi
fi

target_user="${DOCKER_USER:-${SUDO_USER:-}}"
if [[ -n "${target_user}" && "${target_user}" != root ]]; then
  if id "${target_user}" >/dev/null 2>&1; then
    usermod -aG docker "${target_user}"
    log "Пользователь ${target_user} добавлен в группу docker. Для применения нужен новый вход в систему."
  fi
fi

docker --version
docker compose version
restic version
log "Bootstrap завершён. OpenClaw не запускался."
