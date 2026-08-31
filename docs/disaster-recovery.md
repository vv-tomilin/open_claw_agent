# Disaster recovery

## Сценарий полной потери VPS

```text
старый VPS уничтожен
  → новый Debian/Ubuntu amd64 host
  → private Git clone
  → Docker + Compose + restic
  → secrets из password manager
  → соединение с существующим restic repository
  → restore latest в staging
  → offline activation
  → ручной запуск Compose
  → healthcheck и Telegram test
```

## Команды

```bash
git clone <URL_PRIVATE_REPOSITORY> personal-agent
cd personal-agent
cp .env.example .env
nano .env

sudo ./scripts/bootstrap-server.sh
sudo install -d -m 0700 /srv/personal-agent/secrets
sudoedit /srv/personal-agent/secrets/restic-password
sudo chmod 0600 /srv/personal-agent/secrets/restic-password
sudo ./scripts/prepare-host.sh

set -a
. ./.env
set +a
restic snapshots --tag personal-agent

docker compose pull
./scripts/restore.sh latest
./scripts/start.sh
./scripts/healthcheck.sh
```

Не выполняйте `restic init` на существующем repository. Не запускайте новый Gateway, пока старый может оставаться активным.

## Checklist

- [ ] OpenClaw container запускается.
- [ ] Docker/OpenClaw healthcheck проходит.
- [ ] OpenRouter работает после отдельного ручного теста.
- [ ] Telegram принимает сообщение только от одобренного пользователя.
- [ ] Memory существует.
- [ ] Workspace существует.
- [ ] Agents восстановлены.
- [ ] Custom skills обнаруживаются.
- [ ] Scheduled jobs существуют и проверены на безопасный повтор.
- [ ] Durable sessions восстановлены; ограничение по активному хвосту transcript учтено.
- [ ] Pairing и owner identity корректны.
- [ ] Новый backup успешно записывается с новой машины.
- [ ] `make dr-test` проходит.

## Критерий завершения

Recovery считается завершённым только после нового успешного off-site backup. До этого сохраните старый restic snapshot и rollback tree.
