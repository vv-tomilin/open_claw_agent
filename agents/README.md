# Архитектура будущих агентов

Сейчас OpenClaw использует неявный основной агент `main` и общий persistent workspace. Фиктивные агенты не созданы: это инфраструктурный фундамент, а не готовая бизнес-логика.

Будущие роли — Coordinator, Personal Radar, Finance Agent, Market Monitor, Research Agent и News Monitor — следует добавлять через штатный массив `agents.list` в runtime-файле `openclaw.json`. Для каждого агента нужно явно определить:

- стабильный идентификатор и отдельный workspace при необходимости;
- модель или объект `{ primary, fallbacks }`;
- `utilityModel` и модель subagents;
- минимальный tool profile и явные запреты;
- channel bindings, если сообщения должны маршрутизироваться не в `main`;
- границы доступа к персональным и финансовым данным.

Исходные инструкции агента (`AGENTS.md`, `SOUL.md`, шаблоны и несекретные данные) можно хранить в Git. Сессии, memory, базы данных, pairing, credentials и автоматически созданные файлы должны оставаться в `${PERSONAL_AGENT_DATA_DIR}` и попадать только в зашифрованный backup.

Перед добавлением агента проверьте актуальные разделы официальной документации OpenClaw «Multi-agent routing», «Configuration — agents» и «Sub-agents»: формат конфигурации меняется быстрее, чем этот repository.
