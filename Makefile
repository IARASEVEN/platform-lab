# platform-lab — human interface. Run `make help`.
#
# Terraform is always invoked as $(TF) so that OpenTofu works too:
#   TF=tofu make <target>
TF ?= terraform

# Recipes run under bash with pipefail so a failing `terraform output`
# cannot silently feed an empty document to the inventory generator.
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# ansible.cfg reads the vault password from .vault-pass (gitignored). On a
# machine without that file, fall back to prompting for it.
ASK_VAULT = $(if $(wildcard .vault-pass),,--ask-vault-pass)

.DEFAULT_GOAL := help

# Scaffold phase: targets exist so the interface is stable from day one,
# but each one arrives with its milestone. `not-yet` fails loudly instead
# of pretending.
define not-yet
	@echo "make $@: not implemented yet — arrives at $(1)." >&2; exit 1
endef

.PHONY: help check-tools identity observability apps all inventory lint secrets-scan demo clean

help: ## List all targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-tools: ## Verify terraform/ansible/go are present and at pinned versions (M1)
	$(call not-yet,M1)

identity: inventory ## Configure the identity profile (inventory + identity playbook)
	ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/identity.yml $(ASK_VAULT)

observability: ## Provision + configure observability (M2)
	$(call not-yet,M2)

apps: ## Provision + configure apps (M3)
	$(call not-yet,M3)

all: ## Everything (M3, once all profiles exist)
	$(call not-yet,M3)

# Write-then-move: if `terraform output` or jq fails, pipefail aborts the
# recipe and any previously generated hosts.yml survives untouched.
inventory: ## Regenerate ansible/inventory/hosts.yml from Terraform state
	$(TF) -chdir=infra output -json \
		| jq -r -f ansible/inventory/generate.jq > ansible/inventory/hosts.yml.tmp
	mv ansible/inventory/hosts.yml.tmp ansible/inventory/hosts.yml
	@echo "inventory: wrote ansible/inventory/hosts.yml"

# Each lint block activates itself when its files arrive with their
# milestone; until then it says so and moves on. If the files exist but the
# tool is missing, the block fails — lint never silently skips real code.
lint: ## yamllint, ansible-lint, terraform fmt/validate, golangci-lint, promtool (grows per milestone)
	yamllint --strict .
	ansible-lint
	@if [ -n "$$(find infra -name '*.tf' -print -quit)" ]; then \
		$(TF) -chdir=infra fmt -check -recursive && \
		$(TF) -chdir=infra init -backend=false -input=false >/dev/null && \
		$(TF) -chdir=infra validate; \
	else \
		echo "lint: no Terraform yet — skipped (arrives at M1)"; \
	fi
	@if [ -n "$$(find services/observability -name '*.rules.yml' -print -quit)" ]; then \
		find services/observability -name '*.rules.yml' -exec promtool check rules {} +; \
	else \
		echo "lint: no Prometheus rules yet — skipped (arrives at M2)"; \
	fi
	@if [ -f exporters/ipa-cert-exporter/go.mod ]; then \
		cd exporters/ipa-cert-exporter && golangci-lint run; \
	else \
		echo "lint: no Go module yet — skipped (arrives at M4)"; \
	fi

secrets-scan: ## Scan the working tree for secrets with gitleaks
	@command -v gitleaks >/dev/null 2>&1 || \
		{ echo "make $@: gitleaks not found — see https://github.com/gitleaks/gitleaks#installing" >&2; exit 1; }
	gitleaks dir . --redact

demo: ## Scripted end-to-end demo path (M5)
	$(call not-yet,M5)

clean: ## Destroy the lab (M1)
	$(call not-yet,M1)
