.PHONY: install db run test lint autocorrect

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
