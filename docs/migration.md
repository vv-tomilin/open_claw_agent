# Перенос на другую машину

## Плановая миграция

1. Зафиксируйте используемый OpenClaw version и прочитайте release notes.
2. На старом host выполните `./scripts/backup.sh` и `restic check`.
3. Остановите старый Gateway: `./scripts/stop.sh`.
4. Убедитесь, что Telegram bot больше не получает updates на старой машине.
5. На новой машине заполните `.env` теми же recovery-настройками.
6. Выполните `./scripts/setup.sh restore latest`: он подготовит host, подключит restic и восстановит state, но не запустит Gateway.
7. Выполните `make enable-agent-access`: для нового snapshot команда подтвердит текущую политику, а для старого точечно включит полный профиль.
8. Запустите новый Gateway, healthcheck и Telegram test.
9. Создайте backup с новой машины.

## Изменение путей

Host paths можно изменить через `PERSONAL_AGENT_DATA_DIR` и `PERSONAL_AGENT_BACKUP_DIR`. Container paths остаются стабильными `/home/node/.openclaw`, `/home/node/.openclaw/workspace` и `/home/node/.config/openclaw`, поэтому штатный archive переносим между hosts.

## Откат

Не запускайте старую и новую машину одновременно. Если новая машина не проходит healthcheck, остановите её, проанализируйте logs и только затем решите, возвращать ли старую. Restore более старого snapshot является «time travel» для sessions, approvals и delivery state.
