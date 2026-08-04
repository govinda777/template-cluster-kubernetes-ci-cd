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

.PHONY: help config config-aws config-gcp config-azure config-all config-kube aws gcp azure run-pipeline run pipeline

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
	@echo "  make config all   (ou make config-all)   - Onboarding Multicloud Unificado (OIDC Bootstrap)"
	@echo "  make config kube  (ou make config-kube)  - Configurar contexto local do Kubernetes EKS"
	@echo "  make run pipeline (ou make run-pipeline) - Executar a Pipeline Inteira Localmente"
	@echo "  make run clean-slate                    - Executar teste integrado de destruição e reconstrução"
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

config-all:
	@chmod +x scripts/bootstrap-multicloud.sh
	@bash scripts/bootstrap-multicloud.sh

config-kube:
	@chmod +x scripts/configure-kubeconfig.sh
	@bash scripts/configure-kubeconfig.sh

# Trata "make run pipeline" / "make run clean-slate"
run:
	@if [ "$(ACTION)" = "pipeline" ]; then \
		$(MAKE) run-pipeline; \
	elif [ "$(ACTION)" = "clean-slate" ]; then \
		$(MAKE) run-clean-slate; \
	else \
		echo "Erro: Comando inválido. Use 'make run pipeline' ou 'make run clean-slate'"; \
		exit 1; \
	fi

run-pipeline:
	@bash scripts/run-pipeline.sh

run-clean-slate:
	@chmod +x scripts/destroy-recreate-test.sh
	@bash scripts/destroy-recreate-test.sh
