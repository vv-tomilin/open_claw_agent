# Базовые запреты безопасности

1. Не публиковать Gateway напрямую в Интернет. Compose привязывает порт к `127.0.0.1`.
2. Не монтировать Docker socket, `/root`, `~/.ssh` или filesystem host-машины.
3. Не включать `privileged`, host network и elevated tools.
4. Не разрешать shell и filesystem writes за пределами workspace, покупки, переводы, торговлю и произвольную почту.
5. Хранить `.env`, restic password и recovery secrets вне Git.
6. Использовать Telegram `dmPolicy: pairing`; после одобрения первого владельца проверить `commands.ownerAllowFrom`.
7. Считать web/RSS/API контент недоверенным и устойчивым к prompt injection только частично.
8. Перед обновлением всегда создавать и проверять off-site backup.

`no-new-privileges`, сброс `NET_RAW`/`NET_ADMIN`, непривилегированный официальный image и узкие bind mounts уменьшают blast radius. Docker sandbox для agent tools намеренно не включён: shell жёстко запрещён, filesystem tools ограничены workspace через `tools.fs.workspaceOnly`, а подключение Docker socket ради sandbox увеличило бы поверхность атаки.
