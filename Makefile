
SHELL := /bin/sh
DOCKER ?= docker
COMPOSE ?= $(shell docker compose version >/dev/null 2>&1 && echo docker compose || echo docker-compose)
COMPOSE_FILE ?= docker-compose.yaml
COMPOSE_NAME = "iotstack"

OPENSSL ?= openssl
CERT_DAYS ?= 365

.PHONY: init certs up down logs ps reset

init:
	@test -f .env || cp .env.example .env
	@echo "Created .env. Configure passwords and API_TOKEN before starting the stack."

certs:
	@mkdir -p nginx/certs
	@umask 077; $(OPENSSL) req -x509 -newkey rsa:3072 -sha256 -nodes \
		-days $(CERT_DAYS) -config nginx/openssl.cnf \
		-keyout nginx/certs/server.key -out nginx/certs/server.crt
	@echo "Certificate generated in nginx/certs. Restart NGINX after renewing it."

up:
	@test -s nginx/certs/server.crt -a -s nginx/certs/server.key || { echo "Missing TLS certificate: run make certs first."; exit 1; }
	@test -s .env || { echo "Missing environment file: run make init first."; exit 1; }
	$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_NAME) up -d --build

down:
	$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_NAME) down

logs:
	$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_NAME) logs -f

ps:
	$(DOCKER) ps

reset:
	$(COMPOSE) down -v
