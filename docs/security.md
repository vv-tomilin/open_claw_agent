# Безопасность

## Реализовано

- Gateway опубликован только на loopback host.
- Gateway требует случайный token.
- Telegram DMs используют pairing, groups отключены.
- Agent tool profile `full` разрешает shell/runtime, файловые операции, cron, автоматизации, messaging, управление сессиями и доступные Gateway tools основному агенту и подагентам.
- Контейнер не privileged, без Docker socket, host network, SSH keys и полного host filesystem.
- `no-new-privileges`, drop `NET_RAW`/`NET_ADMIN`, официальный non-root image.
- Compose передаёт контейнеру явный allowlist OpenClaw-переменных, а не весь `.env`; restic/R2 credentials остаются на хосте.
- Image version закреплена; logs ограничены по размеру и количеству.
- Secrets/runtime/backups исключены из Git.
- Backup шифруется restic и проверяется штатным OpenClaw verify.

## Trade-offs

Gateway bind внутри Docker должен быть `lan`, иначе Docker port publishing не работает; внешний port при этом ограничен `127.0.0.1`. CLI service разделяет network namespace Gateway по официальной схеме и используется только после старта. Offline scripts используют one-shot Gateway service с CLI entrypoint.

Sandbox Docker для agent tools не включён, потому что потребовал бы Docker socket или отдельную sandbox infrastructure. Полный профиль позволяет агенту менять всё, что доступно внутри контейнера и bind mounts: workspace, runtime config/state, auth-profile keys и локальный `/backup`. Он по-прежнему не даёт доступ к Docker daemon, корню хоста, SSH-ключам оператора и несмонтированным каталогам.

Полный доступ существенно расширяет последствия prompt injection, ошибки модели или компрометации paired-аккаунта: возможны выполнение команд, повреждение state, утечка обязательных OpenClaw-токенов и нежелательные расходы. Поэтому проект предназначен только для отдельной заменяемой машины без посторонних данных и сервисов. Telegram остаётся закрытым через pairing, SSH доступен только оператору, важное состояние регулярно архивируется, а изменения профиля, памяти и scheduled jobs периодически проверяются.

Процесс OpenClaw и shell внутри контейнера видят `OPENROUTER_API_KEY`, `TELEGRAM_BOT_TOKEN` и `OPENCLAW_GATEWAY_TOKEN`, поскольку без них сервис не работает. Контейнер не получает `RESTIC_PASSWORD_FILE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, B2 или REST backend credentials из проектного `.env`. Даже если агент изменит локальный backup staging, удалённые restic snapshots остаются недоступны без host-only credentials.

Systemd backup unit по умолчанию запускается как root ради переносимости шаблона. После setup его можно перевести на deployment-пользователя с UID `OPENCLAW_UID`, доступом к Docker daemon и restic backend credentials; каталоги state/backup/secrets уже принадлежат этому пользователю.

## Секреты

`.env` должен иметь mode `0600`; каталог секретов — `0700`, файл restic password — `0600`. `setup.sh` назначает их deployment-пользователю с UID `OPENCLAW_UID`, поэтому повседневные операции не требуют root. Restic master password обязан храниться также отдельно от host, например в password manager. Потеря master password равна потере backup.

OpenClaw archives содержат credentials и session history. Restic шифрование не отменяет необходимость минимальных permissions и bucket policy. При подозрении на утечку rotate OpenRouter/Telegram/Gateway credentials и создайте новый restic repository/password.

Если агент повредил persistent state, остановите Gateway, не запускайте потенциально повторяемые scheduled jobs и выполните штатный restore из последнего доверенного remote snapshot по [инструкции backup/restore](backup-restore.md). После восстановления ротируйте потенциально раскрытые токены и создайте новый backup.

## Регулярный аудит

```bash
docker compose run --rm openclaw-cli doctor --json
docker compose run --rm openclaw-cli security audit --deep
docker compose run --rm openclaw-cli plugins list --json
make backup-check
```

Проверяйте новые plugins и skills как исполняемый доверенный код. Web/RSS/API content может содержать prompt injection даже при закрытом Telegram.
