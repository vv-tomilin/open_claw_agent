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
# если bootstrap добавил пользователя в группу docker, повторно войти в систему
./scripts/setup.sh restore latest
# ввести существующий master password restic из password manager
# убедиться, что прежний экземпляр полностью выключен
./scripts/start.sh
./scripts/healthcheck.sh
```

`setup.sh restore` не выполняет `restic init` и не запускает Gateway. Он создаёт host-каталоги, запрашивает существующий master password, проверяет доступ к snapshots, загружает image и восстанавливает state. Не запускайте новый Gateway, пока старый может оставаться активным.

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
