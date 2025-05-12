DOCKER_COMPOSE = cd .. && docker-compose
DOCKER_RM =  cd .. && docker rm
DOCKER_VOLUME_RM = cd .. && docker volume rm
DOCKER_CONTAINER_NAME=php8.3
DOCKER_COMMAND=cd .. && docker-compose exec --user root $(DOCKER_CONTAINER_NAME)

ENV ?= dev

##
## Docker
## ------
.PHONY: docker-start
docker-start: ## Start docker
$(DOCKER_COMPOSE) up -d

.PHONY: docker-stop
docker-stop: ## Stop docker
$(DOCKER_COMPOSE) stop

.PHONY: docker-exec
docker-exec: ## Exec php container docker
$(DOCKER_COMPOSE) exec --user root php8.3 /bin/bash

.PHONY: remove-db
remove-db: ## Remove db container and volume and clear cache
$(MAKE) docker-stop
$(DOCKER_RM) cbc-docker_pgsql_1
$(DOCKER_VOLUME_RM) cbc-docker_postgres-data
$(MAKE) docker-start
$(DOCKER_COMMAND) rm -rf var/cache

##
## Install
## ------
.PHONY: composer-install
composer-install: ## Composer install
$(DOCKER_COMMAND) composer install -n

.PHONY: project-install
project-install: ## Project install
$(DOCKER_COMMAND) rm -rf var/cache
$(DOCKER_COMMAND) php bin/console oro:install -vvv --drop-database --application-url=https://cbc.loc --user-name=admin --user-email=admin@example.com --user-firstname=John --user-lastname=Doe --user-password=admin --organization-name=Cbc --timeout=0 --env=prod -n

.PHONY: platform-update
platform-update: ## Platform update
$(DOCKER_COMMAND) rm -rf var/cache/*
$(DOCKER_COMMAND) php bin/console oro:entity-config:cache:clear --no-warmup --env=$(ENV)
$(DOCKER_COMMAND) php bin/console oro:entity-extend:cache:clear --no-warmup --env=$(ENV)
$(DOCKER_COMMAND) php bin/console oro:platform:update --force --env=$(ENV)

##
## General
## ------
.PHONY: full-cache-clear
full-cache-clear: ## Remove var/cache directory and warm up the cache
$(DOCKER_COMMAND) rm -rf var/cache
$(DOCKER_COMMAND) php bin/console cache:clear --env=$(ENV)

.PHONY: cache-clear
cache-clear: ## Clear cache
$(DOCKER_COMMAND) php bin/console cache:clear --env=$(ENV)

.PHONY: cache-remove
cache-remove: ## Remove cache directories
$(DOCKER_COMMAND) rm -rf var/cache/*

.PHONY: queue-start
queue-start: ## Queue start
$(DOCKER_COMMAND) php bin/console oro:message-queue:consume -vv --env=$(ENV)

.PHONY: bundle-list
bundle-list: ## Show bundles list
$(DOCKER_COMMAND) php bin/console debug:container --parameter=kernel.bundles --format=json

.PHONY: log-error
log-error: ## Track ERROR\|CRITICAL records in the log file
$(DOCKER_COMMAND) tail -f var/logs/dev.log | grep "ERROR\|CRITICAL"

##
## Index
## ------
.PHONY: reindex
reindex: ## Reindex search
$(DOCKER_COMMAND) php bin/console oro:search:reindex --env=$(ENV)

##
## Migrations
## ------
.PHONY: db-migration
db-migration: ## Run Database migration
ifndef BUNDLE
$(DOCKER_COMMAND) php bin/console oro:migration:load --force --timeout=900
endif
$(DOCKER_COMMAND) php bin/console oro:migration:load --force --timeout=900 --bundles=$(BUNDLE)

.PHONY: data-migration
data-migration: ## Run Data fixture migration
ifndef BUNDLE
$(DOCKER_COMMAND) php bin/console oro:migration:data:load --env=$(ENV)
endif
$(DOCKER_COMMAND) php bin/console oro:migration:data:load --bundles=$(BUNDLE) --env=$(ENV)

.PHONY: show-migration
show-migration: ## Show migrations
$(DOCKER_COMMAND) php bin/console doctrine:schema:update --dump-sql --env=$(ENV)

.PHONY: doctrine-cache-clear
doctrine-cache-clear: ## Doctrine clear metadata cache
$(DOCKER_COMMAND) php bin/console doctrine:cache:clear-metadata

##
## Trans
## ------
.PHONY: trans-load
trans-load: ## Translation load
$(DOCKER_COMMAND) php bin/console oro:translation:load --env=$(ENV)

.PHONY: trans-dump
trans-dump: ## Translation dump
$(DOCKER_COMMAND) php bin/console oro:translation:dump --env=$(ENV)

##
## Assets
## ------
.PHONY: symlink
symlink: ## Symlink assets
$(DOCKER_COMMAND) php bin/console assets:install --symlink

.PHONY: asset-build
asset-build: ## Build assets
ifndef THEME
$(DOCKER_COMMAND) php bin/console oro:assets:build --env=$(ENV)
endif
$(DOCKER_COMMAND) php bin/console oro:assets:build $(THEME) --env=$(ENV)

##
## Workflow
## ------
.PHONY: workflow-load ## Workflow assets
workflow-load:
$(DOCKER_COMMAND) php bin/console oro:workflow:definitions:load --env=$(ENV)

##
## ORO Entity
## ------
.PHONY: entity-update-schema
entity-update-schema:
$(DOCKER_COMMAND) php bin/console oro:entity-extend:update-schema

.PHONY: entity-update
entity-update:
$(DOCKER_COMMAND) php bin/console oro:entity-extend:update

.PHONY: entity-config-update
entity-config-update:
$(DOCKER_COMMAND) php bin/console oro:entity-config:update

.PHONY: entity-cache-clear
entity-cache-clear:
$(DOCKER_COMMAND) php bin/console oro:entity-extend:cache:clear


##
## ORO API
## ------
.PHONY: api-warmup
api-warmup: ## API cache warmup
$(MAKE) api-cache-clear
$(MAKE) api-doc-cache-clear

.PHONY: api-cache-clear
api-cache-clear: ## API cache clear
$(DOCKER_COMMAND) php bin/console oro:api:cache:clear

.PHONY: api-doc-cache-clear
api-doc-cache-clear: ## API doc cache clear
$(DOCKER_COMMAND) php bin/console oro:api:doc:cache:clear

.PHONY: api-debug-action
api-debug-action: ## API debug action
$(DOCKER_COMMAND) php bin/console oro:api:debug $(ACTION) --request-type=$(REQUEST_TYPE)


##
## Xdebug
## ------
.PHONY: enable-xdebug
enable-xdebug: ## Enable xdebug
$(DOCKER_COMMAND) /enable_xdebug.sh

.PHONY: disable-xdebug
disable-xdebug: ## Disable xdebug
$(DOCKER_COMMAND) /disable_xdebug.sh

##
## Debug
## ------
.PHONY: event-dispatcher
event-dispatcher: ## Output a list of all listeners for the event
$(DOCKER_COMMAND) php bin/console debug:event-dispatcher $(EVENT)

##
## Analysis
## ------
.PHONY: analysis
analysis: ## Run code analysis
$(DOCKER_COMMAND) php bin/phpcs -s --standard=./phpcs.xml --extensions=php --colors src
$(DOCKER_COMMAND) php bin/phpmd ./src text ./vendor/oro/platform/build/phpmd.xml


##
## Additional
## ------
help:
@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-24s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m## /[33m/' && printf "\n"

.PHONY: help

.DEFAULT_GOAL := help

