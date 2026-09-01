## 1. Общая подготовка host

- [x] 1.1 Добавить в `scripts/lib.sh` проверку безопасного управляемого каталога и читаемости restic password file; проверить отказ для широких системных путей и недоступного файла.
- [x] 1.2 Расширить `scripts/prepare-host.sh` поддержкой root и deployment UID, идемпотентным созданием state/backup/secrets и сохранением существующего `openclaw.json`; проверить ветки с совпадающим и несовпадающим UID.
- [x] 1.3 Реализовать скрытый двойной ввод master password, режим `--prompt-restic-password` и permissions `0700/0600`; проверить `--help`, несовпадающие пароли и отсутствие интерактивного терминала.

## 2. Оркестрация нового deployment и restore

- [x] 2.1 Добавить `scripts/setup.sh new` с preflight, ограниченным вызовом `sudo`, различением пустого и существующего restic repository, pull закреплённых images и запуском через `start.sh`; проверить синтаксис и вывод `--help`.
- [x] 2.2 Добавить `scripts/setup.sh restore [latest|SNAPSHOT_ID] [--force]` с обязательным повторным вводом recovery-пароля, проверкой snapshots и делегированием offline restore без запуска Gateway; проверить разбор допустимых и лишних параметров.
- [x] 2.3 Добавить `snapshots` в `backup-maintenance.sh`, Make targets `setup-new`, `setup-restore`, `backup-list` и актуальную подсказку `start.sh`; проверить, что список использует тег `personal-agent`, а `validate.sh` требует `scripts/setup.sh`.

## 3. Пользовательская конфигурация и документация

- [x] 3.1 Уточнить в `.env.example` назначение `OPENCLAW_UID/GID`, пример R2 repository и отдельный password file; проверить POSIX-совместимость загрузки заполненного `.env`.
- [x] 3.2 Обновить README и эксплуатационные документы едиными сценариями `setup.sh new` и `setup.sh restore`, rootless-моделью, permissions и ручным запуском после recovery; проверить поиском, что основной путь не требует ручных `source`, `restic init` и создания secrets-файла.

## 4. Интеграционная проверка

- [x] 4.1 Проверить Bash-синтаксис всех project scripts и справку новых команд; ожидаемый результат — `bash -n` и вызовы `--help` завершаются успешно.
- [x] 4.2 Выполнить `scripts/validate.sh` и `docker compose config --quiet` для рабочих профилей; ожидаемый результат — закреплённая версия, валидные JSON/Compose и наличие обязательных файлов.
- [x] 4.3 Проверить staged diff на отсутствие секретов и незапланированных изменений реализации; ожидаемый результат — change описывает только уже присутствующее поведение, а все пользовательские тексты остаются на русском языке.
