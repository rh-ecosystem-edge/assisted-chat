# Makefile for assisted-chat project
# This Makefile provides convenient targets for managing the assisted-chat services

.PHONY: all build-images generate run resume stop rm logs query query-interactive help

# Default target
all: help

# Build all container images
build-images:
	@echo "Building container images..."
	./scripts/build-images.sh

# Generate configuration files
generate:
	@echo "Generating configuration files..."
	./scripts/generate.sh

# Start the assisted-chat services
run:
	@echo "Starting assisted-chat services..."
	./scripts/run.sh

# Resume the assisted-chat services
resume:
	@echo "Resuming assisted-chat services..."
	./scripts/resume.sh

# Stop the assisted-chat services
stop:
	@echo "Stopping assisted-chat services..."
	./scripts/stop.sh

# Remove/cleanup the assisted-chat services
rm:
	@echo "Removing assisted-chat services..."
	./scripts/rm.sh

# Show logs for the assisted-chat services
logs:
	@echo "Showing logs for assisted-chat services..."
	./scripts/logs.sh

# Query the assisted-chat services
query:
	@echo "Querying assisted-chat services..."
	./scripts/query.sh

# Query the assisted-chat services in interactive mode
query-interactive:
	@echo "Querying assisted-chat services in interactive mode..."
	./scripts/query.sh --interactive

# Show help information
help:
	@echo "Available targets:"
	@echo "  build-images  - Build all container images"
	@echo "  generate      - Generate configuration files"
	@echo "  run           - Start the assisted-chat services"
	@echo "  resume        - Resume the assisted-chat services"
	@echo "  stop          - Stop the assisted-chat services"
	@echo "  rm            - Remove/cleanup the assisted-chat services"
	@echo "  logs          - Show logs for the assisted-chat services"
	@echo "  query         - Query the assisted-chat services"
	@echo "  query-interactive - Query the assisted-chat services in interactive mode"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Example usage:"
	@echo "  make build-images"
	@echo "  make run"
	@echo "  make logs"
	@echo "  make query"
	@echo "  make query-interactive" 
