# Конфигурация

## Два уровня

`config/openclaw.json` — Git-версия начального шаблона. `${PERSONAL_AGENT_DATA_DIR}/openclaw/openclaw.json` — активная runtime-копия. `prepare-host.sh` не перезаписывает существующую runtime-копию.

OpenClaw поддерживает `${UPPERCASE_ENV}` substitution в строковых значениях JSON5. Поэтому модели, токены и Control UI origin передаются через process environment контейнера.

Compose читает `.env` только для подстановки и передаёт контейнеру явный allowlist переменных OpenClaw. Параметры restic, R2/B2/REST credentials и путь к master password остаются у host-скриптов и в process environment агента не попадают.

## Обязательные значения `.env`

- `OPENCLAW_VERSION` — закреплённый стабильный tag;
- `OPENCLAW_GATEWAY_TOKEN` — случайный секрет минимум 32 bytes;
- `OPENROUTER_API_KEY`;
- `PRIMARY_MODEL`, `UTILITY_MODEL`, `HEAVY_MODEL`;
- `TELEGRAM_BOT_TOKEN`;
- абсолютные `PERSONAL_AGENT_DATA_DIR` и `PERSONAL_AGENT_BACKUP_DIR`;
- `RESTIC_REPOSITORY` и `RESTIC_PASSWORD_FILE`.

`OPENCLAW_UID` и `OPENCLAW_GID` должны совпадать с UID/GID непривилегированного пользователя внутри выбранного image (для официального образа по умолчанию `1000:1000`). Если оператор host-машины имеет другой UID, запускайте backup/restore через root либо выделите service user с этим UID; скрипты откажутся менять владельца без достаточных прав.

`RESTIC_PASSWORD_FILE` указывает на защищённый файл вне Git. `setup.sh new` запрашивает новый master password, а `setup.sh restore` — существующий пароль из password manager; вручную создавать файл и настраивать его владельца не требуется.

## Версия image

Обычно задаётся только `OPENCLAW_VERSION`. Необязательный `OPENCLAW_IMAGE` полностью переопределяет reference и удобен для pin по immutable digest. Не используйте `latest`, `main` или beta tag в production без осознанного теста.

## Модели

OpenRouter ref содержит дополнительный namespace: `openrouter/anthropic/...`, `openrouter/openai/...` и так далее. `openrouter/auto` удобен только для первого запуска; production cost/quality лучше контролировать конкретными id.

OpenClaw не имеет отдельного встроенного `heavyModel`. Поэтому `HEAVY_MODEL` — внешний логический alias для operator commands и будущих agent/automation overrides. Он не является fallback автоматически.

## Telegram

Token остаётся только в `.env`; config обращается к нему через env substitution. `dmPolicy: pairing`, `groupPolicy: disabled`. Pairing state хранится в `~/.openclaw/credentials` и входит в backup.

## Инструменты агента

Начальный шаблон использует `tools.profile: full`. Это сознательная конфигурация доверенного агента для выделенной машины: shell, filesystem, cron, автоматизации, session и Gateway tools доступны внутри контейнерной границы. Обязательные токены OpenRouter, Telegram и Gateway доступны процессу и shell контейнера.

`prepare-host.sh` не перезаписывает существующий runtime config. Для точечного перехода старого persistent state используйте `make enable-agent-access`; команда сохраняет остальные настройки и безопасна при повторном запуске.

## Проверка

```bash
docker compose config
docker compose run --rm openclaw-cli config get agents.defaults.model --json
docker compose run --rm openclaw-cli models list --provider openrouter
docker compose run --rm openclaw-cli doctor --json
```

Последние три команды выполняйте после запуска Gateway. Никогда не публикуйте вывод команд, если он может содержать metadata вашей инсталляции.
