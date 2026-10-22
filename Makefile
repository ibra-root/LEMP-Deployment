SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help setup ping check deploy vault-edit vault-view

help: ## Show this help
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

setup: ## Generate local secrets (vault.yml and .vault_pass)
	./scripts/setup-vault.sh

ping: ## Check connectivity to the managed hosts
	ansible all -m ping

check: ## Validate the playbook syntax
	ansible-playbook main_playbook.yaml --syntax-check

deploy: ## Run the full deployment
	ansible-playbook main_playbook.yaml

vault-edit: ## Edit the encrypted secrets
	ansible-vault edit group_vars/all/vault.yml

vault-view: ## Show the encrypted secrets
	ansible-vault view group_vars/all/vault.yml
