#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "${SCRIPT_DIR}/lib.sh"

mode="${1:-forget}"
load_env
require_restic_env

case "${mode}" in
  check)
    log "Проверка целостности restic repository."
    restic check
    ;;
  forget)
    log "Применение retention без дорогостоящего prune."
    restic forget --tag personal-agent \
      --keep-daily "${RESTIC_KEEP_DAILY:-7}" \
      --keep-weekly "${RESTIC_KEEP_WEEKLY:-4}" \
      --keep-monthly "${RESTIC_KEEP_MONTHLY:-6}"
    ;;
  prune)
    log "Применение retention с удалением неиспользуемых данных."
    restic forget --tag personal-agent \
      --keep-daily "${RESTIC_KEEP_DAILY:-7}" \
      --keep-weekly "${RESTIC_KEEP_WEEKLY:-4}" \
      --keep-monthly "${RESTIC_KEEP_MONTHLY:-6}" \
      --prune
    restic check
    ;;
  *) fail "Режим должен быть check, forget или prune." ;;
esac

log "УСПЕХ: операция restic ${mode} завершена."
