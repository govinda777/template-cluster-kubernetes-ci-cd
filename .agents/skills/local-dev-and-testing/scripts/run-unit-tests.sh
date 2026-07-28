#!/usr/bin/env bash

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}⚡ Executando Testes Unitários e Análise Estática (Pre-commit DoD)${NC}"
echo -e "${BLUE}========================================================================${NC}"

# Detectar tofu ou terraform
TOFU_BIN="tofu"
if ! command -v tofu &> /dev/null; then
    TOFU_BIN="terraform"
fi

STATUS=0

# 1. Terraform Format Check
echo "-> Formatando código IaC..."
if ! $TOFU_BIN fmt -check -recursive terraform/; then
    echo -e "${RED}❌ Erro: Formatação do Terraform/OpenTofu incorreta. Execute '$TOFU_BIN fmt -recursive terraform/' para corrigir.${NC}"
    STATUS=1
else
    echo -e "${GREEN}✅ Formatação IaC OK!${NC}"
fi

# 2. Yamllint
if command -v yamllint &> /dev/null; then
    echo "-> Executando yamllint..."
    if ! yamllint -c .yamllint.yml apps-template/ platform-apps/; then
        echo -e "${RED}❌ Erro: Falha na validação de estilo YAML.${NC}"
        STATUS=1
    else
        echo -e "${GREEN}✅ Estilo YAML OK!${NC}"
    fi
else
    echo -e "${YELLOW}ℹ️  yamllint não instalado. Pulando lint de manifestos.${NC}"
fi

# 3. Conftest (OPA Policies)
if command -v conftest &> /dev/null; then
    echo "-> Verificando conformidade com as regras OPA (conftest)..."
    if ! conftest test --policy tests/policies/ apps-template/base/; then
        echo -e "${RED}❌ Erro: Políticas OPA de Kubernetes não cumpridas.${NC}"
        STATUS=1
    else
        echo -e "${GREEN}✅ OPA Policies OK!${NC}"
    fi
else
    echo -e "${YELLOW}ℹ️  conftest não instalado. Pulando verificação Rego/OPA.${NC}"
fi

if [ $STATUS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 Todos os testes unitários locais passaram!${NC}"
else
    echo -e "\n${RED}❌ Falha nos testes unitários locais. Veja os erros acima.${NC}"
fi

exit $STATUS
