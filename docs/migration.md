# Перенос на другую машину

## Плановая миграция

1. Зафиксируйте используемый OpenClaw version и прочитайте release notes.
2. На старом host выполните `./scripts/backup.sh` и `restic check`.
3. Остановите старый Gateway: `./scripts/stop.sh`.
4. Убедитесь, что Telegram bot больше не получает updates на старой машине.
5. На новой машине выполните deployment до `prepare-host.sh`, но не запускайте Gateway.
6. Подключите тот же restic repository и выполните `./scripts/restore.sh latest`.
7. Запустите новый Gateway, healthcheck и Telegram test.
8. Создайте backup с новой машины.

## Изменение путей

Host paths можно изменить через `PERSONAL_AGENT_DATA_DIR` и `PERSONAL_AGENT_BACKUP_DIR`. Container paths остаются стабильными `/home/node/.openclaw`, `/home/node/.openclaw/workspace` и `/home/node/.config/openclaw`, поэтому штатный archive переносим между hosts.

## Откат

Не запускайте старую и новую машину одновременно. Если новая машина не проходит healthcheck, остановите её, проанализируйте logs и только затем решите, возвращать ли старую. Restore более старого snapshot является «time travel» для sessions, approvals и delivery state.
