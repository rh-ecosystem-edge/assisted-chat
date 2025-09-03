# Makefile for assisted-chat project
# This Makefile provides convenient targets for managing the assisted-chat services

.PHONY: all \
	build-images \
	build-inspector build-assisted-mcp build-lightspeed-stack build-lightspeed-plus-llama-stack build-ui \
	generate run resume stop rm logs query query-int query-stage query-prod query-interactive delete mcphost test-eval psql sqlite help
	deploy-template ci-test deploy-template-local

all: help ## Show help information

build-images: ## Build all container images
	@echo "Building container images..."
	./scripts/build-images.sh

build-inspector: ## Build inspector image
	@echo "Building inspector image..."
	./scripts/build-images.sh inspector

build-assisted-mcp: ## Build assisted service MCP image
	@echo "Building assisted service MCP image..."
	./scripts/build-images.sh assisted-mcp

build-lightspeed-stack: ## Build lightspeed stack image
	@echo "Building lightspeed stack image..."
	./scripts/build-images.sh lightspeed-stack

build-lightspeed-plus-llama-stack: ## Build lightspeed stack plus llama stack image
	@echo "Building lightspeed stack plus llama stack image..."
	./scripts/build-images.sh lightspeed-plus-llama-stack

build-ui: ## Build UI image
	@echo "Building UI image..."
	./scripts/build-images.sh ui

deploy-template: ## Used by the CI. Deploys the template on the temporary CI cluster
	scripts/deploy_template.sh

ci-test: ## Used by the CI to test the assisted-chat services
	./scripts/ci_test.sh

deploy-template-local: ## Used to test the CI flow locally. Deploys the template on whatever cluster `oc` is currently logged in to
	@echo "Setting up local secrets directory..."
	@mkdir -p /tmp/secrets/vertex
	@if [ -z "$(VERTEX_SERVICE_ACCOUNT_PATH)" ]; then \
		echo "Error: VERTEX_SERVICE_ACCOUNT_PATH environment variable must be set"; \
		exit 1; \
	fi
	@if [ -z "$(ASSISTED_CHAT_IMG)" ]; then \
		echo "Error: ASSISTED_CHAT_IMG environment variable must be set"; \
		exit 1; \
	fi
	@cp "$(VERTEX_SERVICE_ACCOUNT_PATH)" /tmp/secrets/vertex/service_account
	@echo "Deploying template locally..."
	oc create namespace assisted-chat || true
	NAMESPACE=assisted-chat SECRETS_BASE_PATH=/tmp/secrets ASSISTED_CHAT_IMG="$(ASSISTED_CHAT_IMG)" scripts/deploy_template.sh

generate: ## Generate configuration files
	@echo "Generating configuration files..."
	./scripts/generate.sh

run: ## Start the assisted-chat services
	@echo "Starting assisted-chat services..."
	./scripts/run.sh

resume: ## Resume the assisted-chat services
	@echo "Resuming assisted-chat services..."
	./scripts/resume.sh

stop: ## Stop the assisted-chat services
	@echo "Stopping assisted-chat services..."
	./scripts/stop.sh

rm: ## Remove/cleanup the assisted-chat services
	@echo "Removing assisted-chat services..."
	./scripts/rm.sh

logs: ## Show logs for the assisted-chat services
	@echo "Showing logs for assisted-chat services..."
	./scripts/logs.sh

query: ## Query the assisted-chat services (localhost)
	@echo "Querying assisted-chat services (localhost)..."
	./scripts/query.sh

query-int: ## Query the assisted-chat services (integration environment)
	@echo "Querying assisted-chat services (integration environment)..."
	QUERY_ENV=int ./scripts/query.sh

query-stage: ## Query the assisted-chat services (stage environment)
	@echo "Querying assisted-chat services (stage environment)..."
	QUERY_ENV=stage ./scripts/query.sh

query-prod: ## Query the assisted-chat services (production environment)
	@echo "Querying assisted-chat services (production environment)..."
	QUERY_ENV=prod ./scripts/query.sh

query-interactive: query ## Query the assisted-chat services (deprecated, use 'query')
	@echo "WARNING: 'query-interactive' is deprecated. Use 'make query' instead."

delete: ## Delete a conversation from assisted-chat services
	@echo "Deleting conversation from assisted-chat services..."
	DELETE_MODE=true ./scripts/query.sh

mcphost: ## Attach to mcphost
	@echo "Attaching to mcphost..."
	./scripts/mcphost.sh

test-eval: ## Run agent evaluation tests
	@echo "Refreshing OCM token..."
	@. utils/ocm-token.sh && get_ocm_token && echo "$$OCM_TOKEN" > test/evals/ocm_token.txt
	@echo "Running agent evaluation tests..."
	@cd test/evals && python eval.py

psql: ## Connect to PostgreSQL database in the assisted-chat pod
	@echo "Connecting to PostgreSQL database..."
	@podman exec -it assisted-chat-pod-postgres env PGOPTIONS='-c search_path="lightspeed-stack",public' psql -U assisted-chat -d assisted-chat

sqlite: ## Copy SQLite database from pod and open in browser
	@echo "Copying SQLite database from pod..."
	@podman cp assisted-chat-pod-lightspeed-stack:/tmp/assisted-chat.db /tmp/assisted-chat.db
	@echo "Opening SQLite database in browser..."
	@sqlitebrowser /tmp/assisted-chat.db

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Example usage:"
	@echo "  make build-images"
	@echo "  make run"
	@echo "  make logs"
	@echo "  make query"
	@echo "  make query-int"
	@echo "  make query-stage"
	@echo "  make query-interactive"
	@echo "  make test-eval"
