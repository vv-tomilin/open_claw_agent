# Инфраструктура персонального AI-агента

Переносимый Git-ready проект для одного self-hosted OpenClaw на Debian/Ubuntu x86_64. Машина считается заменяемой, конфигурация воспроизводится из Git, состояние живёт вне контейнера, секреты остаются вне Git, а восстановление выполняется из зашифрованного off-site restic repository.

## Рекомендуемая среда

Проект по умолчанию включает доверенному агенту полный профиль инструментов OpenClaw: shell/runtime, чтение и запись доступных контейнеру файлов, cron и автоматизации, управление сессиями и доступные инструменты Gateway. Это позволяет агенту самостоятельно сохранять профиль и память, выполнять команды и создавать периодические задачи без ручного запуска CLI оператором.

Разворачивайте эту конфигурацию только на отдельной заменяемой машине — VPS, VM или физическом сервере, выделенном специально под агента. На ней не должно быть посторонних рабочих нагрузок, личных файлов, браузерных профилей, SSH-ключей и аккаунтов, не относящихся к OpenClaw. Разрешайте SSH только оператору, оставляйте Telegram в режиме pairing и регулярно проверяйте внешний backup.

Не используйте этот профиль на общей рабочей станции или сервере с чувствительными данными и сервисами. Ошибка модели, prompt injection или компрометация одобренного Telegram-аккаунта могут привести к выполнению команд, изменению persistent state, расходам и чтению обязательных токенов OpenRouter, Telegram и Gateway внутри контейнера.

## Что содержит repository

- Docker Compose deployment на официальном закреплённом image OpenClaw;
- исходный шаблон безопасной конфигурации OpenRouter и Telegram;
- bind mounts для state, workspace и auth-profile secret keys;
- штатный OpenClaw backup, дополнительно защищённый restic;
- restore, disaster recovery test, update и healthcheck;
- systemd templates для backup и integrity check;
- документацию операций, миграции и безопасности.

## Архитектура

```text
PRIVATE GIT REPOSITORY                 БУДУЩИЙ DEBIAN/UBUNTU HOST
compose + config template ──────────► Docker Compose ─► OpenClaw Gateway
scripts + docs + skills                      │
                                             ├─ /srv/personal-agent/state
                                             │  ├─ openclaw
                                             │  ├─ workspace
                                             │  └─ auth-profile-secrets
                                             │
                                             └─ штатный OpenClaw archive
                                                        │
                                                        ▼
                                              restic (шифрование)
                                                        │
                                                        ▼
                                              удалённое хранилище
```

Gateway публикуется только на `127.0.0.1`. Для удалённого Control UI используйте SSH tunnel или другой аутентифицированный приватный канал, но не меняйте bind на публичный адрес без отдельного threat review.

## Структура каталогов

```text
.
├── compose.yaml
├── .env.example
├── Makefile
├── config/openclaw.json
├── agents/README.md
├── skills/README.md
├── policies/
├── scripts/
├── systemd/
└── docs/
```

Полное назначение компонентов описано в [архитектуре](docs/architecture.md), а сверенные upstream-механизмы — в [решениях по OpenClaw](docs/openclaw-decisions.md).

## Требования

- Debian 12/Ubuntu 22.04 или новее, архитектура amd64;
- Docker Engine и Docker Compose plugin;
- restic, curl, jq, make;
- минимум 2 ГБ RAM, рекомендуется 4 ГБ;
- приватный Git repository и удалённое хранилище для restic.

Если Docker и Docker Compose уже установлены, остальные системные зависимости на Debian/Ubuntu можно установить отдельно:

```bash
sudo apt-get update
sudo apt-get install -y restic curl jq make
```

Проверьте установку:

```bash
restic version
curl --version
jq --version
make --version
```

`scripts/bootstrap-server.sh` устанавливает эти зависимости из официального Docker apt repository. Не запускайте его на рабочей станции: он предназначен только для будущего сервера.

## Первый deployment

Если Docker, Compose и restic уже установлены, полный пользовательский сценарий состоит из настройки `.env` и одной команды:

```bash
git clone <URL_PRIVATE_REPOSITORY> personal-agent
cd personal-agent

cp .env.example .env
nano .env

./scripts/setup.sh new
```

`setup.sh` проверит конфигурацию, при необходимости один раз вызовет `sudo` для каталогов `/srv`, запросит master password restic без вывода на экран, создаст restic repository, загрузит закреплённый image и запустит Gateway. Пароль не попадает в shell history.

На совсем чистом сервере сначала установите зависимости:

```bash
sudo ./scripts/bootstrap-server.sh
```

Если пользователь был добавлен в группу `docker`, войдите в систему повторно, затем запускайте `setup.sh new`. Для повседневной работы без `sudo` рекомендуется deployment-пользователь с UID `1000`, совпадающим с пользователем официального image. При другом UID можно запустить весь сценарий через `sudo ./scripts/setup.sh new`. Подробности: [первое развёртывание](docs/deployment.md).

## Конфигурация

`.env` является единственным обязательным локальным файлом параметров. `prepare-host.sh` один раз копирует `config/openclaw.json` в persistent state. После этого OpenClaw может безопасно изменять runtime-копию, не загрязняя Git.

Все значения `PLACEHOLDER_*` должны быть заменены. Версия меняется одной строкой `OPENCLAW_VERSION`; полный `OPENCLAW_IMAGE` нужен только для необязательного pin по digest.

Новая установка сразу получает полный профиль. Если persistent state был создан старой версией проекта или восстановлен из старого snapshot, шаблон намеренно не перезаписывает его. После обновления Git-копии выполните:

```bash
make backup
make enable-agent-access
```

`make enable-agent-access` точечно меняет только политику `tools`, проверяет конфигурацию и перезапускает работающий Gateway. Повторный запуск безопасен; модели, Telegram pairing, профиль, память и остальные пользовательские настройки сохраняются.

## OpenRouter

Используются нативные поля OpenClaw:

- `agents.defaults.model.primary` ← `PRIMARY_MODEL`;
- `agents.defaults.utilityModel` ← `UTILITY_MODEL`;
- `agents.defaults.subagents.model` ← `UTILITY_MODEL`;
- `HEAVY_MODEL` хранится как роль для явного `--model` или будущей automation.

Ключ берётся из `OPENROUTER_API_KEY` в `.env` и явно передаётся процессу OpenClaw. При полном профиле shell-команды внутри контейнера могут прочитать этот ключ, как и токены Telegram и Gateway. Ссылки моделей имеют формат `openrouter/<provider>/<model>`. Подробности: [конфигурация](docs/configuration.md) и [политика моделей](policies/models.md).

## Telegram

1. В BotFather выполните `/newbot` и сохраните token в password manager.
2. Запишите token в `TELEGRAM_BOT_TOKEN` внутри `.env`.
3. Запустите Gateway и отправьте боту обычное сообщение. `/start` сам по себе может не создать pairing request.
4. Просмотрите запросы:

   ```bash
   docker compose run --rm openclaw-cli pairing list telegram
   ```

5. Одобрите только свой одноразовый код:

   ```bash
   docker compose run --rm openclaw-cli pairing approve telegram <КОД>
   ```

6. Если owner ещё не был задан, CLI approval должен автоматически записать ваш Telegram id первым `commands.ownerAllowFrom`. Проверьте это, оставьте `dmPolicy: pairing` и не одобряйте другие запросы. Группы по умолчанию отключены.

## Persistent state

По умолчанию host хранит:

```text
/srv/personal-agent/
├── state/
│   ├── openclaw/                # config, agents, sessions, memory, runtime DB
│   ├── workspace/               # рабочие материалы и memory-файлы
│   └── auth-profile-secrets/    # локальные ключи шифрования auth profiles
├── backups/                     # только краткоживущий staging
└── secrets/restic-password      # вне Git
```

Удаление контейнера не удаляет эти bind mounts.

## Запуск и остановка

```bash
make up
make health
make logs
make restart
make down
```

`make health` не выполняет платный LLM request. Явная платная проверка — `make test-llm` с интерактивным подтверждением.

## Резервные копии

```bash
make backup
make backup-list
make backup-check
make backup-maintenance
./scripts/backup-maintenance.sh prune   # запускать отдельно и не слишком часто
```

Backup создаётся штатным `openclaw backup create --verify`, поэтому canonical SQLite снимается безопасным `VACUUM INTO`, а не `cp`. Затем архив и auth-profile secret keys отправляются в зашифрованный restic repository. `.env` намеренно не архивируется: ключи нужно восстановить из password manager.

Важно: OpenClaw `v2026.7.1-2` намеренно исключает из горячего архива активные session transcripts и другие volatile-файлы. Durable state и завершённые данные защищены, но для сохранения самого свежего незавершённого диалога нужен дополнительный cold filesystem/VM snapshot при остановленном Gateway.

## Восстановление

На новой машине после заполнения `.env` существующими credentials:

```bash
./scripts/setup.sh restore latest
```

Скрипт запросит существующий master password restic, подготовит каталоги, проверит repository, загрузит image и восстановит state. Gateway намеренно не запускается: сначала убедитесь, что старый экземпляр выключен. Если snapshot был создан до включения полного профиля, выполните `make enable-agent-access`, затем `./scripts/start.sh`.

Для конкретного snapshot используйте `./scripts/setup.sh restore <SNAPSHOT_ID>`. Если обнаружено реальное существующее состояние, нужен явный третий параметр `--force`. Старое дерево перемещается в `${PERSONAL_AGENT_BACKUP_DIR}/pre-restore-*`. Подробнее: [backup и restore](docs/backup-restore.md).

## Обновление

1. Вручную измените только `OPENCLAW_VERSION` в `.env`.
2. Изучите release notes и совместимость state/schema.
3. Выполните `make update`.

Скрипт создаёт off-site backup, загружает закреплённый image, перезапускает Gateway и выполняет healthcheck. Автоматического перехода на `latest` и downgrade нет.

## Перенос на другой сервер

Остановите старый экземпляр, выполните `make backup`, затем следуйте [migration](docs/migration.md). Никогда не запускайте одновременно два экземпляра с одним Telegram token и восстановленным delivery state.

## Disaster recovery

Кратко:

```bash
git clone <URL_PRIVATE_REPOSITORY> personal-agent
cd personal-agent
cp .env.example .env
# заполнить .env значениями из password manager
sudo ./scripts/bootstrap-server.sh
# после повторного входа в систему:
./scripts/setup.sh restore latest
# убедиться, что старый экземпляр выключен:
make enable-agent-access
./scripts/start.sh
./scripts/healthcheck.sh
```

Полный checklist: [disaster recovery](docs/disaster-recovery.md). Безопасная репетиция без запуска бота: `make dr-test`.

## Разделение данных

```text
GIT
├── compose и scripts
├── документация
├── несекретный config template
└── исходники custom skills

ТОЛЬКО SERVER
├── .env
├── runtime state и databases
├── локальные credentials
└── временный backup staging

ЗАШИФРОВАННЫЙ RESTIC BACKUP
├── штатный OpenClaw archive
│   ├── config и agent state
│   ├── memory, sessions и workspace
│   ├── consistent runtime DB
│   └── channel/provider auth state
└── auth-profile secret keys

PASSWORD MANAGER
├── restic master password
├── OpenRouter API key
├── Telegram token
├── Gateway token
└── recovery secrets
```

## Безопасность

Агент получает полный профиль инструментов внутри контейнера и может изменять workspace, runtime state и доступный контейнеру локальный backup staging. При этом Compose не использует `privileged`, Docker socket, host network, `/root` или `~/.ssh`; включены `no-new-privileges`, сброс `NET_RAW`/`NET_ADMIN`, loopback publishing и ротация Docker logs.

Compose не передаёт контейнеру весь `.env`: restic master password и ключи Cloudflare R2 остаются у host-скриптов, поэтому агент не может удалить или расшифровать удалённые snapshots только через своё окружение. Обязательные для OpenClaw токены OpenRouter, Telegram и Gateway доступны процессу и shell внутри контейнера. Детали, остаточные риски и порядок восстановления: [security](docs/security.md) и [backup/restore](docs/backup-restore.md).

## Диагностика

```bash
make validate
make setup-new
make setup-restore SNAPSHOT=latest
make enable-agent-access
docker compose ps
docker compose logs --tail=200 openclaw-gateway
curl -fsS http://127.0.0.1:18789/healthz
docker compose run --rm openclaw-cli doctor --json
make backup-list
```

Если `openclaw-cli` сообщает, что Gateway недоступен, сначала запустите `openclaw-gateway`: официальный CLI service разделяет его network namespace и является post-start инструментом. Offline backup/verify scripts поэтому запускают CLI entrypoint через one-shot `openclaw-gateway` service.
