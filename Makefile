# ==============================================================================
# Makefile - Plataforma Multi-Cloud (AWS, GCP, Azure)
# Repositório: template-cluster-kubernetes-ci-cd
# ==============================================================================

SHELL := /usr/bin/env bash

.PHONY: help config config-aws config-gcp config-azure aws gcp azure

# Trata argumentos dinâmicos para aceitar a sintaxe "make config aws"
ifeq ($(firstword $(MAKECMDGOALS)),config)
  PROVIDER := $(word 2,$(MAKECMDGOALS))
  $(eval $(PROVIDER):;@:)
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
