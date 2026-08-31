# Эксплуатация

## Ежедневно

- проверить `docker compose ps` и Docker health status;
- просмотреть ошибки `docker compose logs --tail=200 openclaw-gateway`;
- убедиться, что systemd backup timer завершился успешно.

## Еженедельно

- `restic snapshots --tag personal-agent`;
- `make backup-check`;
- проверить pairing requests, owner identity и scheduled jobs;
- контролировать disk usage state/media/logs.

## Ежемесячно

- `make dr-test`;
- применить retention и при необходимости отдельный `prune`;
- проверить актуальность OpenClaw release и security notes;
- сверить recovery secrets в password manager.

## Команды

```bash
make validate
make up
make down
make restart
make logs
make health
make backup
make backup-check
make backup-maintenance
make restore SNAPSHOT=latest
make update
make dr-test
```

`make restore` с существующим state требует `RESTORE_FLAGS=--force`. Перед этим вручную остановите Gateway и создайте backup.

## Scheduled jobs OpenClaw

Задания cron работают внутри Gateway и сохраняются в общей SQLite state database. В закреплённой версии управляйте ими штатной CLI (`openclaw cron list|add|edit|remove`), а не ручным редактированием runtime databases. Перед restore проверьте, не повторит ли старое расписание побочные действия.

## Инцидент

1. Остановите Gateway, если есть риск компрометации.
2. Сохраните logs и metadata без публикации секретов.
3. Rotate затронутые keys/tokens.
4. Не удаляйте последний исправный restic snapshot.
5. Восстанавливайте только доверенный, проверенный archive.
6. После recovery выполните security audit и новый backup.
