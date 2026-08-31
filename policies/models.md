# Политика моделей

OpenRouter является единственным разрешённым model provider по умолчанию. Ссылки на модели имеют формат `openrouter/<provider>/<model>`.

- `PRIMARY_MODEL` — обычные диалоги и основные agent turns.
- `UTILITY_MODEL` — короткие внутренние операции и subagents.
- `HEAVY_MODEL` — зарезервированная роль для явных сложных задач и будущих automations; OpenClaw не имеет отдельного встроенного поля «heavy model», поэтому значение не включено в автоматический fallback.

В `openclaw.json` используются штатные `agents.defaults.model.primary`, `agents.defaults.utilityModel` и `agents.defaults.subagents.model`. Автоматические fallback-модели по умолчанию отключены, чтобы неожиданная ошибка не переключала запрос на потенциально более дорогую модель.

Для разовой сложной задачи оператор может передать `${HEAVY_MODEL}` в поддерживаемую команду `--model`, а для постоянной роли — добавить отдельный agent или model override в automation. Модели меняются только в `.env`, без перестройки image.
