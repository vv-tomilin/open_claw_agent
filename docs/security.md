# Безопасность

## Реализовано

- Gateway опубликован только на loopback host.
- Gateway требует случайный token.
- Telegram DMs используют pairing, groups отключены.
- Agent tool profile разрешает web/memory/message/subagents, но запрещает shell, filesystem writes, Gateway и cron control.
- Контейнер не privileged, без Docker socket, host network, SSH keys и полного host filesystem.
- `no-new-privileges`, drop `NET_RAW`/`NET_ADMIN`, официальный non-root image.
- Image version закреплена; logs ограничены по размеру и количеству.
- Secrets/runtime/backups исключены из Git.
- Backup шифруется restic и проверяется штатным OpenClaw verify.

## Trade-offs

Gateway bind внутри Docker должен быть `lan`, иначе Docker port publishing не работает; внешний port при этом ограничен `127.0.0.1`. CLI service разделяет network namespace Gateway по официальной схеме и используется только после старта. Offline scripts используют one-shot Gateway service с CLI entrypoint.

Sandbox Docker для agent tools не включён, потому что потребовал бы Docker socket или отдельную sandbox infrastructure. Вместо этого опасные runtime/fs tools отсутствуют на policy layer. Это уменьшает функциональность, но соответствует read/monitor/report use case.

Systemd backup unit по умолчанию запускается как root. Отдельный service user безопаснее, но требует site-specific UID, ownership, Docker group и restic backend credentials; это оставлено оператору, чтобы template не сломал portable deployment.

## Секреты

`.env` должен иметь mode `0600`; parent secret directory — `0700`. Restic master password обязан храниться отдельно от host, например в password manager. Потеря master password равна потере backup.

OpenClaw archives содержат credentials и session history. Restic шифрование не отменяет необходимость минимальных permissions и bucket policy. При подозрении на утечку rotate OpenRouter/Telegram/Gateway credentials и создайте новый restic repository/password.

## Регулярный аудит

```bash
docker compose run --rm openclaw-cli doctor --json
docker compose run --rm openclaw-cli security audit --deep
docker compose run --rm openclaw-cli plugins list --json
restic check
```

Проверяйте новые plugins и skills как исполняемый доверенный код. Web/RSS/API content может содержать prompt injection даже при закрытом Telegram.
