.PHONY: help new-project test-api test-admin quality-api quality-admin docker-up docker-down

SHELL := /bin/bash

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

new-project: ## Scaffold a new API+Admin project pair (interactive)
	bash new-project.sh

test-api: ## Run all tests in ci4-api-starter
	cd ci4-api-starter && composer test

test-admin: ## Run all tests in ci4-admin-starter
	cd ci4-admin-starter && vendor/bin/phpunit --no-coverage

quality-api: ## Run full quality suite in ci4-api-starter (PHPStan + tests + CS-Fixer)
	cd ci4-api-starter && composer quality

quality-admin: ## Run full quality suite in ci4-admin-starter (PHPStan + CS-Fixer)
	cd ci4-admin-starter && composer ci

docker-up: ## Start both sub-projects via Docker Compose
	@echo "Starting API..."
	cd ci4-api-starter && docker compose up -d
	@echo "Starting Admin..."
	cd ci4-admin-starter && docker compose up -d

docker-down: ## Stop both sub-projects
	cd ci4-api-starter && docker compose down
	cd ci4-admin-starter && docker compose down
