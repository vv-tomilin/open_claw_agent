## Why

Первичное развёртывание и восстановление персонального агента требовали ручного создания каталогов и файла пароля, экспорта `.env`, прямых вызовов restic и Docker Compose. Уже реализованный единый setup-сценарий нужно зафиксировать как проверяемый контракт, чтобы перенос на новую машину оставался воспроизводимым и не зависел от скрытых ручных шагов.

## What Changes

- Добавляется единая команда `setup.sh new` для подготовки host, безопасного ввода пароля restic, инициализации нового repository, загрузки закреплённых images и запуска Gateway.
- Добавляется единая команда `setup.sh restore` для подключения существующего repository, выбора snapshot и безопасного offline-восстановления без автоматического запуска Gateway.
- Подготовка host поддерживает root и deployment-пользователя с UID, совпадающим с `OPENCLAW_UID`, и при необходимости ограниченно повышает права только для создания каталогов.
- Каталоги state, backup и secrets, файл пароля restic и `.env` получают заданные владельца и режимы доступа; небезопасные широкие пути для secrets отклоняются.
- Проектные команды сами загружают `.env`, проверяют доступность restic password file и предоставляют отдельную команду просмотра snapshots с тегом `personal-agent`.
- README и эксплуатационная документация описывают одинаковые короткие сценарии нового deployment и disaster recovery.

## Capabilities

### New Capabilities

- `portable-agent-deployment`: Воспроизводимое первичное развёртывание и восстановление персонального агента с безопасной подготовкой host, restic и контролем запуска Gateway.

### Modified Capabilities

Нет: основные OpenSpec capabilities в проекте ранее не были определены.

## Impact

- Скрипты: `scripts/setup.sh`, `scripts/prepare-host.sh`, `scripts/lib.sh`, `scripts/start.sh`, `scripts/backup-maintenance.sh`, `scripts/validate.sh`.
- Интерфейсы оператора: `.env.example`, `Makefile`, `README.md` и документация в `docs/`.
- Внешние зависимости и системы: Docker Engine, Docker Compose plugin, restic, jq, sudo при недоступных для записи host-каталогах и удалённый restic backend.
- Формат persistent state и существующие low-level backup/restore-команды не меняются.
