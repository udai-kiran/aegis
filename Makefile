.PHONY: up down dev-up dev-down logs ps clean env

COMPOSE := docker compose --env-file .env.local
DEV_COMPOSE := $(COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml

env:
	@test -f .env.local || (cp .env.local.example .env.local && echo "Created .env.local from .env.local.example")

up: env
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

dev-up: env
	$(DEV_COMPOSE) up -d

dev-down:
	$(DEV_COMPOSE) down

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v
