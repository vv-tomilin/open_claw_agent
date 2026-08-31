# Пользовательские skills

Каталог `skills/` хранится в Git и монтируется read-only в `${OPENCLAW_WORKSPACE_DIR}/skills`. Каждый skill размещается в отдельном подкаталоге и содержит `SKILL.md` в формате, который поддерживает текущая версия OpenClaw.

Пример:

```text
skills/
└── daily-report/
    ├── SKILL.md
    ├── scripts/
    └── references/
```

В Git допустимы инструкции, проверенные скрипты, шаблоны и небольшие несекретные справочники. Нельзя добавлять API keys, токены, OAuth state, выгрузки персональных данных, runtime-кэш и результаты работы агента.

После изменения skills перезапустите Gateway или выполните штатное обновление списка skills, если это предусмотрено используемой версией OpenClaw. Команда `openclaw skills list` помогает проверить обнаружение. Generated plugin skill index не переносится вручную: OpenClaw восстанавливает его из metadata.

Skills из Git не заменяют persistent workspace. Workspace, memory и сессии находятся на host-машине и входят в штатный архив OpenClaw.
