# Первое развёртывание

Все команды выполняются пользователем вручную на новой Debian/Ubuntu amd64 машине. Этот repository сам никуда не подключается.

## 1. Клонирование и секреты

```bash
git clone <URL_PRIVATE_REPOSITORY> personal-agent
cd personal-agent
cp .env.example .env
nano .env
```

Заполните все `PLACEHOLDER_*`. Получите Telegram token через официальный BotFather, OpenRouter key — в аккаунте OpenRouter, Gateway token сгенерируйте командой `openssl rand -hex 32`.

## 2. Зависимости host-машины

Предварительно прочитайте скрипт, затем:

```bash
sudo ./scripts/bootstrap-server.sh
```

Скрипт поддерживает Debian/Ubuntu amd64, использует официальный Docker apt repository, устанавливает Compose plugin и restic, но не запускает OpenClaw. После добавления пользователя в группу `docker` выйдите из сессии и войдите снова.

## 3. Restic password

```bash
sudo install -d -m 0700 /srv/personal-agent/secrets
sudoedit /srv/personal-agent/secrets/restic-password
sudo chmod 0600 /srv/personal-agent/secrets/restic-password
```

Файл содержит одну строку master password. Копия password должна находиться в password manager вне сервера.

## 4. Persistent state

```bash
sudo ./scripts/prepare-host.sh
```

Скрипт создаёт bind-mount sources с UID/GID из `.env`, устанавливает initial config только при его отсутствии и валидирует Compose. Контейнер не запускается.

Последующие backup/restore-команды можно запускать обычным пользователем, если его UID совпадает с `OPENCLAW_UID` (типичный первый пользователь Debian/Ubuntu — `1000`). При другом UID используйте отдельного service user или запускайте эти операции через `sudo`, сохраняя тот же `.env`.

## 5. Restic repository

Для совершенно нового пустого destination:

```bash
set -a
. ./.env
set +a
restic init
restic snapshots
```

Не выполняйте `restic init`, если repository уже существует: для disaster recovery сразу используйте `restic snapshots`.

## 6. Image и запуск

```bash
docker compose pull
./scripts/start.sh
docker compose ps
```

Откройте `http://127.0.0.1:18789` локально на host либо через SSH tunnel, выполненный вами вручную с доверенного компьютера. Gateway token вводится в Control UI.

## 7. Telegram pairing

Отправьте созданному боту личное сообщение, затем:

```bash
docker compose run --rm openclaw-cli pairing list telegram
docker compose run --rm openclaw-cli pairing approve telegram <КОД>
```

Код действует ограниченное время. Одобряйте только собственный запрос. После первого approval проверьте owner identity и не включайте public DMs.

## 8. Финальные проверки

```bash
./scripts/healthcheck.sh
docker compose run --rm openclaw-cli doctor --json
docker compose run --rm openclaw-cli security audit --deep
./scripts/backup.sh
./scripts/disaster-recovery-test.sh
```

`make test-llm` выполняется отдельно и только после понимания стоимости запроса.

## 9. Установка systemd timers

Templates предполагают системный запуск backup scripts. Отредактируйте путь в конфигурации:

```bash
sudo cp systemd/personal-agent.conf.example /etc/personal-agent.conf
sudoedit /etc/personal-agent.conf

sudo cp systemd/personal-agent-backup.service /etc/systemd/system/
sudo cp systemd/personal-agent-backup.timer /etc/systemd/system/
sudo cp systemd/personal-agent-backup-check.service /etc/systemd/system/
sudo cp systemd/personal-agent-backup-check.timer /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now personal-agent-backup.timer
sudo systemctl enable --now personal-agent-backup-check.timer
systemctl list-timers 'personal-agent-*'
```

Unit запускается как root, потому что должен читать protected secrets и обращаться к Docker daemon. Это осознанный trade-off; scripts имеют узкую задачу, `NoNewPrivileges=true` и `UMask=0077`. На более строгом host создайте отдельного service user с доступом только к project/data/restic и адаптируйте unit.
