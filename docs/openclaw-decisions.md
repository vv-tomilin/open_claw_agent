# Решения по OpenClaw

Документация и release metadata проверены 31 августа 2026 года. Для production default выбран последний стабильный hotfix `2026.7.1-2`, а не `latest`, `main` или beta. Перед реальным deployment повторно проверьте release notes и существование image tag: upstream развивается быстро.

## Image и Docker

Официальный registry — `ghcr.io/openclaw/openclaw`. Compose повторяет существенные части upstream Docker topology для `v2026.7.1-2`: `openclaw-gateway`, post-start `openclaw-cli`, non-root home, bind mounts, HTTP healthcheck через Node, drop `NET_RAW`/`NET_ADMIN` и `no-new-privileges`.

- [Официальная инструкция Docker](https://docs.openclaw.ai/install/docker)
- [Официальный GHCR package](https://github.com/openclaw/openclaw/pkgs/container/openclaw)
- [Upstream Compose закреплённой версии](https://github.com/openclaw/openclaw/blob/v2026.7.1-2/docker-compose.yml)
- [Официальные releases](https://github.com/openclaw/openclaw/releases)

## Persistent paths

Используются документированные container paths:

- `/home/node/.openclaw` — state/config/agents/sessions;
- `/home/node/.openclaw/workspace` — workspace;
- `/home/node/.config/openclaw` — auth-profile encryption keys.

Host sources параметризованы через `.env` и не встроены в image.

## Backup и restore

У стабильной `v2026.7.1-2` есть штатные `backup create --verify` и `backup verify`: они консистентно снимают принадлежащие OpenClaw SQLite databases, config, credentials, agents и workspace, а затем проверяют структуру и manifest. Whole-archive restore command в этой версии отсутствует. Официальная документация обновления предписывает распаковать проверенный archive в staging и применить mapping `sourcePath → archivePath` из `manifest.json` офлайн; именно так работает `restore.sh`.

- [Справочник backup для закреплённой v2026.7.1-2](https://github.com/openclaw/openclaw/blob/v2026.7.1-2/docs/cli/backup.md)
- [Официальное руководство безопасного обновления/restore](https://docs.openclaw.ai/install/updating)

Restic не заменяет штатную консистентность, а добавляет provider-neutral encryption, retention и off-site storage.

Ограничение upstream `v2026.7.1-2`: горячий archive исключает активные session transcripts и другие volatile-файлы. Это защищает консистентное durable state, но не обещает сохранение последнего незавершённого диалога. Для такого RPO нужен отдельный cold filesystem/VM snapshot при остановленном Gateway.

## OpenRouter и модели

`OPENROUTER_API_KEY`, model refs `openrouter/<provider>/<model>`, `agents.defaults.model.primary`, `utilityModel` и `subagents.model` являются штатными механизмами. Отдельного native `heavyModel` нет; `HEAVY_MODEL` остаётся operator-defined ролью.

- [OpenRouter provider](https://docs.openclaw.ai/openrouter)
- [Выбор моделей](https://docs.openclaw.ai/concepts/models)
- [Subagents](https://docs.openclaw.ai/tools/subagents)

## Telegram

Token можно передавать переменной `TELEGRAM_BOT_TOKEN`; default secure access flow — DM pairing с `pairing list` и `pairing approve`. Approved allowlist state хранится в credentials и входит в state backup.

- [Telegram](https://docs.openclaw.ai/telegram)
- [Pairing](https://docs.openclaw.ai/start/pairing)

## Health, jobs и security

Контейнерный liveness endpoint — `/healthz`; image содержит собственный Docker healthcheck. Scheduled jobs принадлежат Gateway и сохраняются в shared state, поэтому repository не редактирует их файлы вручную. Для доверенного агента на выделенной машине выбран `tools.profile: full`; host isolation обеспечивается непривилегированным контейнером и узкими mounts. Compose не использует `env_file`, чтобы restic/R2 credentials из проектного `.env` не попадали агенту автоматически.

- [Health в Docker](https://docs.openclaw.ai/install/docker#health-checks)
- [Automations](https://docs.openclaw.ai/cron-jobs)
- [Security](https://docs.openclaw.ai/security)
- [Tool profiles](https://docs.openclaw.ai/gateway/config-tools)
