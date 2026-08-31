#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

load_env
require_command docker
require_value PRIMARY_MODEL
printf 'ВНИМАНИЕ: эта ручная проверка выполнит платный запрос к модели %s. Продолжить? [д/Н] ' "${PRIMARY_MODEL}"
read -r answer
[[ "${answer}" =~ ^[ДдYy]$ ]] || fail "Проверка отменена."
compose run -T --rm openclaw-cli agent --agent main \
  --model "${PRIMARY_MODEL}" --message "Ответь одним словом: работает"
