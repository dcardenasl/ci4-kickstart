.PHONY: help new-project

SHELL := /bin/bash

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

new-project: ## Scaffold a new API+Admin project pair (interactive)
	bash new-project.sh
