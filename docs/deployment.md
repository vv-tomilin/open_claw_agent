# Первое развёртывание

Все команды выполняются пользователем вручную на новой Debian/Ubuntu amd64 машине. Этот repository сам никуда не подключается.

## 0. Выделенная машина

Штатная конфигурация даёт агенту полный набор инструментов внутри контейнера. Используйте отдельный VPS/VM/сервер без посторонних данных, пользовательских SSH-ключей, браузерных профилей и чувствительных сервисов. Доступ по SSH оставьте только оператору; не разворачивайте проект на общей рабочей станции.

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

## 3. Deployment-пользователь

Официальный image использует непривилегированного пользователя с UID/GID `1000:1000`. Самый простой вариант — выполнять deployment пользователем host-машины с UID `1000`, состоящим в группе `docker`. Тогда `sudo` понадобится только один раз для создания `/srv/personal-agent`.

Проверьте окружение:

```bash
id -u
id -g
docker ps
```

Если UID отличается, используйте специально созданного deployment-пользователя с UID `1000` либо запускайте весь setup через `sudo`. Не меняйте `OPENCLAW_UID/GID` без проверки пользователя внутри выбранного image.

## 4. Новый экземпляр

Для нового пустого restic repository выполните:

```bash
./scripts/setup.sh new
```

Сценарий автоматически:

- проверяет `.env`, Docker, Compose и restic;
- при необходимости один раз запрашивает `sudo` для создания `/srv/personal-agent`;
- создаёт persistent directories с владельцем `OPENCLAW_UID/GID`;
- интерактивно запрашивает master password restic и сохраняет его с mode `0600`;
- устанавливает initial `openclaw.json`, не перезаписывая существующий;
- выполняет `restic init`;
- загружает закреплённый image;
- запускает Gateway и healthcheck.

Новый экземпляр сразу получает профиль `tools.profile: full`, поэтому агент может выполнять shell-команды, записывать persistent state и создавать cron-задачи из доверенной сессии.

Пароль restic храните также в password manager. Если `/srv` уже подготовлен администратором и доступен deployment-пользователю, setup работает полностью без root. При несовпадении UID запустите:

```bash
sudo ./scripts/setup.sh new
```

`prepare-host.sh` остаётся доступен как низкоуровневая идемпотентная операция, но при обычном deployment отдельно запускать его не требуется.

Если persistent state уже существовал до включения полного профиля, сначала создайте backup, затем мигрируйте только tool policy:

```bash
make backup
make enable-agent-access
```

## 5. Проверка запуска

Откройте `http://127.0.0.1:18789` локально на host либо через SSH tunnel, выполненный вами вручную с доверенного компьютера. Gateway token вводится в Control UI.

## 6. Telegram pairing

Отправьте созданному боту личное сообщение, затем:

```bash
docker compose run --rm openclaw-cli pairing list telegram
docker compose run --rm openclaw-cli pairing approve telegram <КОД>
```

Код действует ограниченное время. Одобряйте только собственный запрос. После первого approval проверьте owner identity и не включайте public DMs.

## 7. Финальные проверки

```bash
./scripts/healthcheck.sh
docker compose run --rm openclaw-cli doctor --json
docker compose run --rm openclaw-cli security audit --deep
./scripts/backup.sh
./scripts/disaster-recovery-test.sh
```

`make test-llm` выполняется отдельно и только после понимания стоимости запроса.

## 8. Установка systemd timers

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

Шаблон unit по умолчанию запускается как root для максимальной переносимости между серверами. После `setup.sh` это не обязательно: можно добавить в service `User=<deployment-пользователь>`, `Group=<его-группа>` и `SupplementaryGroups=docker`. Этот пользователь должен иметь UID `OPENCLAW_UID`, доступ к project/data/restic и возможность обращаться к Docker daemon.
