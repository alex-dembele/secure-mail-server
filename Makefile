.PHONY: help init build test lint clean deploy

# Variables
PROJECT_NAME := mailserver-k8s
VERSION := $(shell cat VERSION)
REGISTRY := ghcr.io/your-org
NAMESPACE := mail

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(GREEN)$(PROJECT_NAME) - Makefile Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

init: ## Initialize development environment
	@echo "$(GREEN)Initializing development environment...$(NC)"
	@mkdir -p services/{postfix,dovecot,rspamd,opendkim,clamav,admin-api,web-ui,caldav-carddav}
	@mkdir -p infra/{helm/mailserver,terraform,manifests}
	@mkdir -p database/{migrations,schemas}
	@mkdir -p scripts/{backup,restore,migration,testing}
	@mkdir -p tests/{unit,integration,e2e}
	@mkdir -p docs/{architecture,operations}
	@mkdir -p monitoring/{grafana,prometheus}
	@mkdir -p .github/workflows
	@touch services/postfix/.gitkeep
	@touch services/dovecot/.gitkeep
	@touch database/migrations/.gitkeep
	@echo "$(GREEN)✓ Directory structure created$(NC)"

build: ## Build all Docker images (multi-arch)
	@echo "$(GREEN)Building Docker images...$(NC)"
	@docker buildx create --use --name mailserver-builder 2>/dev/null || true
	@docker buildx build --platform linux/amd64,linux/arm64 -t $(REGISTRY)/postfix:$(VERSION) ./services/postfix --load
	@docker buildx build --platform linux/amd64,linux/arm64 -t $(REGISTRY)/dovecot:$(VERSION) ./services/dovecot --load
	@docker buildx build --platform linux/amd64,linux/arm64 -t $(REGISTRY)/rspamd:$(VERSION) ./services/rspamd --load
	@echo "$(GREEN)✓ Images built successfully$(NC)"

build-local: ## Build images for local architecture only
	@echo "$(GREEN)Building Docker images (local arch)...$(NC)"
	@docker build -t $(REGISTRY)/postfix:$(VERSION) ./services/postfix
	@docker build -t $(REGISTRY)/dovecot:$(VERSION) ./services/dovecot
	@docker build -t $(REGISTRY)/rspamd:$(VERSION) ./services/rspamd
	@echo "$(GREEN)✓ Local images built$(NC)"

test: test-unit test-integration ## Run all tests

test-unit: ## Run unit tests
	@echo "$(GREEN)Running unit tests...$(NC)"
	@cd tests/unit && python -m pytest -v --cov=../../services --cov-report=html
	@echo "$(GREEN)✓ Unit tests passed$(NC)"

test-integration: ## Run integration tests
	@echo "$(GREEN)Running integration tests...$(NC)"
	@cd tests/integration && python -m pytest -v
	@echo "$(GREEN)✓ Integration tests passed$(NC)"

test-e2e: ## Run end-to-end tests (requires K8s cluster)
	@echo "$(GREEN)Running e2e tests...$(NC)"
	@./scripts/testing/smoke-test.sh
	@echo "$(GREEN)✓ E2E tests passed$(NC)"

lint: lint-yaml lint-docker lint-python ## Run all linters

lint-yaml: ## Lint YAML files
	@echo "$(GREEN)Linting YAML files...$(NC)"
	@yamllint -c .yamllint.yml .
	@echo "$(GREEN)✓ YAML linting passed$(NC)"

lint-docker: ## Lint Dockerfiles
	@echo "$(GREEN)Linting Dockerfiles...$(NC)"
	@find services -name Dockerfile -exec hadolint {} \;
	@echo "$(GREEN)✓ Dockerfile linting passed$(NC)"

lint-python: ## Lint Python code
	@echo "$(GREEN)Linting Python code...$(NC)"
	@flake8 services/admin-api
	@black --check services/admin-api
	@echo "$(GREEN)✓ Python linting passed$(NC)"

lint-helm: ## Lint Helm charts
	@echo "$(GREEN)Linting Helm charts...$(NC)"
	@helm lint infra/helm/mailserver
	@echo "$(GREEN)✓ Helm chart linting passed$(NC)"

security-scan: ## Run security scans on images
	@echo "$(GREEN)Running security scans...$(NC)"
	@trivy image $(REGISTRY)/postfix:$(VERSION)
	@trivy image $(REGISTRY)/dovecot:$(VERSION)
	@trivy image $(REGISTRY)/rspamd:$(VERSION)
	@echo "$(GREEN)✓ Security scans completed$(NC)"

helm-package: ## Package Helm chart
	@echo "$(GREEN)Packaging Helm chart...$(NC)"
	@helm package infra/helm/mailserver -d dist/
	@echo "$(GREEN)✓ Helm chart packaged$(NC)"

deploy-dev: ## Deploy to development environment
	@echo "$(GREEN)Deploying to development...$(NC)"
	@helm upgrade --install mailserver ./infra/helm/mailserver \
		-f infra/helm/mailserver/values-dev.yaml \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait
	@echo "$(GREEN)✓ Deployed to development$(NC)"

deploy-staging: ## Deploy to staging environment
	@echo "$(GREEN)Deploying to staging...$(NC)"
	@helm upgrade --install mailserver ./infra/helm/mailserver \
		-f infra/helm/mailserver/values-staging.yaml \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait
	@echo "$(GREEN)✓ Deployed to staging$(NC)"

deploy-prod: ## Deploy to production environment
	@echo "$(YELLOW)⚠ Deploying to PRODUCTION...$(NC)"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@helm upgrade --install mailserver ./infra/helm/mailserver \
		-f infra/helm/mailserver/values-prod.yaml \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait
	@echo "$(GREEN)✓ Deployed to production$(NC)"

undeploy: ## Remove deployment from current namespace
	@echo "$(YELLOW)Removing deployment...$(NC)"
	@helm uninstall mailserver --namespace $(NAMESPACE)
	@echo "$(GREEN)✓ Deployment removed$(NC)"

logs: ## Show logs from all pods
	@kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=mailserver --tail=100 -f

status: ## Show deployment status
	@echo "$(GREEN)Deployment Status:$(NC)"
	@kubectl get all -n $(NAMESPACE)
	@echo ""
	@echo "$(GREEN)Helm Release:$(NC)"
	@helm list -n $(NAMESPACE)

clean: ## Clean build artifacts and temporary files
	@echo "$(GREEN)Cleaning build artifacts...$(NC)"
	@rm -rf dist/ build/ *.egg-info
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete
	@docker buildx rm mailserver-builder 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

backup: ## Create backup of mail data
	@echo "$(GREEN)Creating backup...$(NC)"
	@./scripts/backup/full-backup.sh
	@echo "$(GREEN)✓ Backup created$(NC)"

restore: ## Restore from backup
	@echo "$(YELLOW)Starting restore process...$(NC)"
	@./scripts/restore/restore-full.sh
	@echo "$(GREEN)✓ Restore completed$(NC)"

docs: ## Generate documentation
	@echo "$(GREEN)Generating documentation...$(NC)"
	@cd docs && make html
	@echo "$(GREEN)✓ Documentation generated in docs/_build/html/$(NC)"

dev-setup: init ## Setup complete development environment
	@echo "$(GREEN)Setting up development environment...$(NC)"
	@pip install -r requirements-dev.txt
	@npm install
	@pre-commit install
	@echo "$(GREEN)✓ Development environment ready$(NC)"

version: ## Show current version
	@echo "$(GREEN)Current version: $(VERSION)$(NC)"

bump-version: ## Bump version (usage: make bump-version VERSION=0.2.0)
	@echo "$(GREEN)Updating version to $(VERSION)...$(NC)"
	@echo "$(VERSION)" > VERSION
	@git add VERSION
	@git commit -m "chore: bump version to $(VERSION)"
	@git tag -a "v$(VERSION)" -m "Release version $(VERSION)"
	@echo "$(GREEN)✓ Version bumped to $(VERSION)$(NC)"
	@echo "$(YELLOW)Don't forget to: git push && git push --tags$(NC)"