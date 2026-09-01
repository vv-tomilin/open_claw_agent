SHELL := /usr/bin/env bash

.PHONY: validate setup-new setup-restore prepare up down restart logs health backup backup-list backup-check backup-maintenance restore update dr-test test-llm

validate:
	@./scripts/validate.sh

setup-new:
	@./scripts/setup.sh new

setup-restore:
	@./scripts/setup.sh restore $(SNAPSHOT) $(RESTORE_FLAGS)

prepare:
	@sudo ./scripts/prepare-host.sh

up:
	@./scripts/start.sh

down:
	@./scripts/stop.sh

restart:
	@./scripts/stop.sh
	@./scripts/start.sh

logs:
	@docker compose logs --follow --tail=200 openclaw-gateway

health:
	@./scripts/healthcheck.sh

backup:
	@./scripts/backup.sh

backup-list:
	@./scripts/backup-maintenance.sh snapshots

backup-check:
	@./scripts/backup-maintenance.sh check

backup-maintenance:
	@./scripts/backup-maintenance.sh forget

restore:
	@./scripts/restore.sh $(SNAPSHOT) $(RESTORE_FLAGS)

update:
	@./scripts/update.sh

dr-test:
	@./scripts/disaster-recovery-test.sh

test-llm:
	@./scripts/test-llm.sh
