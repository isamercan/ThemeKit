# Local developer entry points. The CI gates run here for $0 — no Actions minutes.
# `make ci` is the same set of checks GitHub runs; see docs/CI.md.

.DEFAULT_GOAL := help
.PHONY: help ci ci-fast build test lint format hooks screenshots skill mcp-data mcp clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-10s\033[0m %s\n", $$1, $$2}'

ci: ## Run all CI gates locally (format-lint + lint + build + test)
	@bash scripts/ci.sh

ci-fast: ## Build + test only (skip style gates)
	@bash scripts/ci.sh --fast

build: ## Build the package + tests
	swift build --build-tests

test: ## Run the test suite
	swift test

lint: ## SwiftLint
	swiftlint lint --quiet

format: ## Apply SwiftFormat
	swiftformat .

hooks: ## Install the pre-push CI hook
	@bash scripts/install-hooks.sh

screenshots: ## Render component screenshots + rebuild the README gallery
	@bash scripts/gen-screenshots.sh

record-gif: ## Record a Demo-app interaction → GIF (NAME=SelectBox [SECS=7]); tap the component during recording
	@bash scripts/record-gif.sh "$(NAME)" "$(SECS)"

skill: ## Regenerate the skill refs + llms.txt/llms-components.txt from source, and publish the llms.* set to website/public/
	@python3 tools/gen_skill.py

mcp-data: ## Rebuild the MCP data from the DocC symbol graph + tokens (mcp/data/themekit.json)
	@cd mcp && npm install --silent && npm run build:data

mcp: mcp-data ## Build the ThemeKit MCP server (mcp/dist)
	@cd mcp && npm run build

clean: ## Remove build artifacts
	rm -rf .build .ci-test.log
