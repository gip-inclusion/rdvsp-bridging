.PHONY: install db run test lint autocorrect deploy

CONTAINER_NAME ?= rdvsp-bridging

# Ruby is managed by rv; set RUN= if your shell already has the right Ruby
RUN ?= rv run

install: db ## Install gems and prepare the database
	$(RUN) bundle install
	$(RUN) bin/rails db:prepare

db: ## Start the local Postgres container
	docker compose up -d db

run: db ## Start the app (web + GoodJob in-process)
	$(RUN) bin/rails server -p 3010

test: db ## Run the test suite
	$(RUN) bundle exec rspec

lint: ## Run linters
	$(RUN) bundle exec rubocop
	$(RUN) bundle exec brakeman --quiet --no-pager

autocorrect: ## Auto-fix rubocop offenses
	$(RUN) bundle exec rubocop -A

deploy: ## Build, push and redeploy the Scaleway container (needs SCW_REGISTRY and a configured scw CLI)
	@test -n "$$SCW_REGISTRY" || { echo "error: SCW_REGISTRY not set"; exit 1; }
	docker buildx build --platform linux/amd64 -t "$$SCW_REGISTRY/$(CONTAINER_NAME):latest" . --push
	@container_id=$$(scw container container list name=$(CONTAINER_NAME) -o json | jq -r '.[0].id'); \
	test -n "$$container_id" && test "$$container_id" != "null" || { echo "error: no container named $(CONTAINER_NAME)"; exit 1; }; \
	scw container container redeploy "$$container_id" region=fr-par
