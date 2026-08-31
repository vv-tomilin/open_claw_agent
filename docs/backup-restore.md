# Backup и restore

## Что именно защищается

`openclaw backup create --verify` включает state, active config, auth profiles, channel/provider credentials, sessions, configured agent directories и workspace. В `v2026.7.1-2` canonical SQLite снимается штатным `VACUUM INTO` и проверяется на целостность. Дополнительно bundle включает внешний каталог `auth-profile-secrets`.

Штатный горячий архив намеренно пропускает изменяемые файлы без гарантированной restore-ценности: активные session transcripts, cron run logs, rolling logs, delivery queues, socket/PID/temp-файлы. История завершённых сессий и durable state остаются в scope, но самый свежий хвост выполняющегося диалога может отсутствовать. Если нужна побайтовая фиксация этого хвоста, сначала остановите Gateway и дополнительно снимите cold filesystem/VM snapshot каталогов из `PERSONAL_AGENT_DATA_DIR`.

`.env` не входит в backup. OpenRouter key, Telegram token, Gateway token и restic master password восстанавливаются из password manager. Это не позволяет одному украденному restic credential автоматически раскрыть и все operational secrets без содержимого repository и password manager.

## Создание

```bash
./scripts/backup.sh
restic snapshots --tag personal-agent
```

Последовательность:

```text
environment validation
  → штатный consistent OpenClaw archive
  → openclaw verify
  → bundle с auth-profile secret keys
  → restic encryption/upload
  → проверка наличия snapshot
  → удаление local staging
```

## Retention

```bash
./scripts/backup-maintenance.sh forget
./scripts/backup-maintenance.sh check
./scripts/backup-maintenance.sh prune
```

`forget` применяет daily/weekly/monthly retention и не запускает дорогой prune. `prune` запускайте реже в окно обслуживания.

## Restore на пустой host

```bash
./scripts/restore.sh latest
```

Или конкретный snapshot:

```bash
restic snapshots --tag personal-agent
./scripts/restore.sh <SNAPSHOT_ID>
```

Скрипт требует остановленный Gateway и восстанавливает restic только во временный каталог. В закреплённой `v2026.7.1-2` нет whole-archive restore command, поэтому выполняются официальный `openclaw backup verify`, безопасная распаковка в новый staging, проверка `manifest.json` и только затем offline activation.

`prepare-host.sh` создаёт initial template, который не считается реальным state. Любые дополнительные state/workspace/auth файлы приводят к отказу. Для осознанной замены:

```bash
./scripts/stop.sh
./scripts/backup.sh
./scripts/restore.sh latest --force
```

Старое дерево перемещается в `pre-restore-<UTC_TIMESTAMP>`, а не удаляется. Скрипт не запускает Gateway.

## После restore

1. Проверьте вывод `doctor --json`.
2. Убедитесь, что исходный экземпляр выключен.
3. Проверьте Telegram pairing/owner и pending approvals.
4. Запустите `./scripts/start.sh`.
5. Выполните healthcheck, Telegram test и новый backup.

Restore означает возврат delivery/dedupe/approval state во времени. Не повторяйте потенциально side-effecting jobs автоматически. Downloadable plugin `node_modules` не входят в штатный archive; переустановите/обновите нужные plugins и выполните `openclaw skills list`.

## Проверка без production

```bash
./scripts/disaster-recovery-test.sh
```

Тест восстанавливает latest в временный каталог, выполняет официальный verify/restore, при наличии `sqlite3` дополнительно запускает `PRAGMA integrity_check`, после чего удаляет staging. Gateway, Telegram и agent jobs не запускаются.
