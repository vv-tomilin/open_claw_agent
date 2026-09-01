# Безопасность

## Реализовано

- Gateway опубликован только на loopback host.
- Gateway требует случайный token.
- Telegram DMs используют pairing, groups отключены.
- Agent tool profile разрешает web/memory/message/subagents и filesystem-операции только внутри workspace, но запрещает shell, Gateway и cron control.
- Контейнер не privileged, без Docker socket, host network, SSH keys и полного host filesystem.
- `no-new-privileges`, drop `NET_RAW`/`NET_ADMIN`, официальный non-root image.
- Image version закреплена; logs ограничены по размеру и количеству.
- Secrets/runtime/backups исключены из Git.
- Backup шифруется restic и проверяется штатным OpenClaw verify.

## Trade-offs

Gateway bind внутри Docker должен быть `lan`, иначе Docker port publishing не работает; внешний port при этом ограничен `127.0.0.1`. CLI service разделяет network namespace Gateway по официальной схеме и используется только после старта. Offline scripts используют one-shot Gateway service с CLI entrypoint.

Sandbox Docker для agent tools не включён, потому что потребовал бы Docker socket или отдельную sandbox infrastructure. Runtime tools отсутствуют на policy layer, а `tools.fs.workspaceOnly: true` ограничивает `read`/`write`/`edit`/`apply_patch` каталогом `/home/node/.openclaw/workspace`. Это позволяет сохранять bootstrap-профиль и memory-файлы, но не даёт агенту читать `.env`, runtime config, restic secrets или host filesystem за пределами workspace.

Запись в workspace расширяет последствия prompt injection: недоверенный web-контент теоретически может склонить агента изменить memory или рабочие материалы. Поэтому Telegram остаётся закрытым через pairing, shell запрещён, важное состояние регулярно архивируется, а изменения профиля и памяти следует периодически просматривать.

Systemd backup unit по умолчанию запускается как root ради переносимости шаблона. После setup его можно перевести на deployment-пользователя с UID `OPENCLAW_UID`, доступом к Docker daemon и restic backend credentials; каталоги state/backup/secrets уже принадлежат этому пользователю.

## Секреты

`.env` должен иметь mode `0600`; каталог секретов — `0700`, файл restic password — `0600`. `setup.sh` назначает их deployment-пользователю с UID `OPENCLAW_UID`, поэтому повседневные операции не требуют root. Restic master password обязан храниться также отдельно от host, например в password manager. Потеря master password равна потере backup.

OpenClaw archives содержат credentials и session history. Restic шифрование не отменяет необходимость минимальных permissions и bucket policy. При подозрении на утечку rotate OpenRouter/Telegram/Gateway credentials и создайте новый restic repository/password.

## Регулярный аудит

```bash
docker compose run --rm openclaw-cli doctor --json
docker compose run --rm openclaw-cli security audit --deep
docker compose run --rm openclaw-cli plugins list --json
make backup-check
```

Проверяйте новые plugins и skills как исполняемый доверенный код. Web/RSS/API content может содержать prompt injection даже при закрытом Telegram.
