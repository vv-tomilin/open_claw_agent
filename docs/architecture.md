# Архитектура

## Цели

Проект оптимизирован для одного владельца и одной активной инсталляции: простота, переносимость, воспроизводимость и проверяемое восстановление важнее высокой доступности.

## Компоненты

1. Private Git хранит Compose, scripts, documentation, config template и custom skill source.
2. Официальный image `ghcr.io/openclaw/openclaw:<версия>` запускает Gateway и ephemeral CLI.
3. Три bind mount сохраняют state, workspace и auth-profile encryption keys.
4. OpenRouter подключается стандартной переменной `OPENROUTER_API_KEY`.
5. Telegram подключается через `TELEGRAM_BOT_TOKEN` и нативный DM pairing.
6. OpenClaw создаёт консистентный полный archive; restic шифрует его и отправляет off-site.
7. systemd host-машины только вызывает repository scripts по расписанию.

## Границы доверия

Контейнер доверен как закреплённый официальный artifact, но не получает широкого доступа к host. Repository не доверяет входящему web-контенту и Telegram-отправителям до pairing. Restic repository считается потенциально наблюдаемым storage: конфиденциальность обеспечивается master password, который хранится отдельно.

## Почему нет дополнительных компонентов

Kubernetes, Swarm, Terraform, Ansible, Vault, PostgreSQL, Redis, reverse proxy, Prometheus и CI/CD не нужны для одного процесса и усложнили бы recovery. Docker logging с ротацией, health endpoint и restic покрывают базовые эксплуатационные требования.

## Поток восстановления

```text
новый host
  ├─ Git возвращает deployment
  ├─ password manager возвращает ключи
  ├─ restic возвращает проверенный OpenClaw archive
  ├─ offline activation возвращает persistent tree
  └─ Compose запускает тот же закреплённый Gateway
```

## Ограничение active-active

Два экземпляра с одним Telegram token или восстановленным delivery/dedupe state не поддерживаются. Перед запуском новой машины старый Gateway должен быть гарантированно выключен.
