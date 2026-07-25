# ==============================================================================
# Makefile - Plataforma Multi-Cloud (AWS, GCP, Azure)
# Repositório: template-cluster-kubernetes-ci-cd
# ==============================================================================

-include .aws_profile_env
export AWS_PROFILE
export AWS_REGION

-include .gcp_profile_env
export GCP_PROJECT_ID
export GCP_REGION
export GCP_ZONE

SHELL := /usr/bin/env bash

.PHONY: help config config-aws config-gcp config-azure aws gcp azure run-pipeline run pipeline

# Trata argumentos dinâmicos para aceitar a sintaxe "make config aws" e "make run pipeline"
ifeq ($(firstword $(MAKECMDGOALS)),config)
  PROVIDER := $(word 2,$(MAKECMDGOALS))
  $(eval $(PROVIDER):;@:)
endif

ifeq ($(firstword $(MAKECMDGOALS)),run)
  ACTION := $(word 2,$(MAKECMDGOALS))
  $(eval $(ACTION):;@:)
endif

# Alvo padrão
help:
	@echo "========================================================================"
	@echo "  Plataforma Multi-Cloud - Automação e Autenticação Local"
	@echo "========================================================================"
	@echo "Uso disponível:"
	@echo "  make config aws   (ou make config-aws)   - Configurar/Autenticar na AWS"
	@echo "  make config gcp   (ou make config-gcp)   - Configurar/Autenticar no GCP"
	@echo "  make config azure (ou make config-azure) - Configurar/Autenticar na Azure"
	@echo "  make run pipeline (ou make run-pipeline) - Executar a Pipeline Inteira Localmente"
	@echo "========================================================================"

# Regra principal para rota com espaço
config:
	@if [ -z "$(PROVIDER)" ]; then \
		echo "Erro: Especifique o provedor de nuvem. Exemplo: make config aws ou make config-aws"; \
		exit 1; \
	fi
	@$(MAKE) config-$(PROVIDER)

# Targets específicos por nuvem
config-aws:
	@bash scripts/config-aws.sh

config-gcp:
	@bash scripts/config-gcp.sh

config-azure:
	@bash scripts/config-azure.sh

# Trata "make run pipeline" direcionando para "make run-pipeline"
run:
	@if [ "$(ACTION)" = "pipeline" ]; then \
		$(MAKE) run-pipeline; \
	else \
		echo "Erro: Comando inválido. Use 'make run pipeline' ou 'make run-pipeline'"; \
		exit 1; \
	fi

run-pipeline:
	@bash scripts/run-pipeline.sh
