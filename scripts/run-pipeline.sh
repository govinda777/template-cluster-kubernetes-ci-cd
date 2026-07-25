#!/usr/bin/env bash

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🚀 Iniciando Execução Local da Pipeline Completa (CI/CD)${NC}"
echo -e "${BLUE}========================================================================${NC}"

# 0. Detectar comando Terraform / OpenTofu disponível
TOFU_BIN="tofu"
if ! command -v tofu &> /dev/null; then
    TOFU_BIN="terraform"
fi
echo -e "\n🔍 ${BLUE}[00] Detectando Ferramenta IaC... Usando: ${YELLOW}$TOFU_BIN${NC}\n"

# 1. Static Linting & Security
echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}⚡ [01] Executando Análise Estática, Formatação e Segurança (Linting)${NC}"
echo -e "${BLUE}========================================================================${NC}"
echo "-> Formatando código Terraform/OpenTofu..."
$TOFU_BIN fmt -check -recursive terraform/ || echo -e "${YELLOW}⚠️  Aviso: Problemas de formatação encontrados.${NC}"

if command -v yamllint &> /dev/null; then
    echo "-> Executando yamllint..."
    yamllint -c .yamllint.yml apps-template/ platform-apps/ || echo -e "${YELLOW}⚠️  Aviso: Erros de estilo YAML encontrados.${NC}"
else
    echo -e "${YELLOW}ℹ️  yamllint não está instalado localmente. Pulando lint de manifests.${NC}"
fi

if command -v tfsec &> /dev/null; then
    echo "-> Executando tfsec..."
    tfsec terraform/ --soft-fail
else
    echo -e "${YELLOW}ℹ️  tfsec não está instalado localmente. Pulando análise de segurança Terraform.${NC}"
fi

if command -v trivy &> /dev/null; then
    echo "-> Executando Trivy..."
    trivy config --severity HIGH,CRITICAL --exit-code 0 .
else
    echo -e "${YELLOW}ℹ️  Trivy não está instalado localmente. Pulando escaneamento de vulnerabilidades.${NC}"
fi

if command -v conftest &> /dev/null; then
    echo "-> Executando conftest (Políticas Rego/OPA)..."
    conftest test --policy tests/policies/ apps-template/base/ || exit 1
    conftest test --policy tests/policies/ apps-template/overlays/prod/xperience-climb/ || exit 1
else
    echo -e "${YELLOW}ℹ️  conftest não está instalado localmente. Pulando validação OPA.${NC}"
fi

# 2. OpenTofu Dev Environment
echo -e "\n${BLUE}========================================================================${NC}"
echo -e "${BLUE}🛠️  [02] Executando Automação IaC para Ambiente de Desenvolvimento (Dev)${NC}"
echo -e "${BLUE}========================================================================${NC}"
echo "-> Inicializando Dev..."
cd terraform/live/dev
$TOFU_BIN init
echo "-> Validando Dev..."
$TOFU_BIN validate
echo "-> Planejando Dev..."
$TOFU_BIN plan -out=tfplan

echo -e "${YELLOW}-> Deseja aplicar o plano de Desenvolvimento localmente? (Aperte Enter para pular, escreva 'yes' para aplicar)${NC}"
read -r CONFIRM
if [ "$CONFIRM" = "yes" ]; then
    echo "-> Aplicando Dev..."
    $TOFU_BIN apply -auto-approve tfplan
else
    echo "-> Etapa 'apply' de Desenvolvimento pulada."
fi
cd ../../..

# 3. OpenTofu Prod Environment
echo -e "\n${BLUE}========================================================================${NC}"
echo -e "${BLUE}🏗️  [03] Executando Automação IaC para Ambiente de Produção (Prod)${NC}"
echo -e "${BLUE}========================================================================${NC}"
echo "-> Inicializando Prod..."
cd terraform/live/prod
$TOFU_BIN init
echo "-> Validando Prod..."
$TOFU_BIN validate
echo "-> Planejando Prod..."
$TOFU_BIN plan -out=tfplan

echo -e "${YELLOW}-> Deseja aplicar o plano de Produção localmente? (Aperte Enter para pular, escreva 'yes' para aplicar)${NC}"
read -r CONFIRM
if [ "$CONFIRM" = "yes" ]; then
    echo "-> Aplicando Prod..."
    $TOFU_BIN apply -auto-approve tfplan
else
    echo "-> Etapa 'apply' de Produção pulada."
fi
cd ../../..

# 4. Terratest Integration Suite
echo -e "\n${BLUE}========================================================================${NC}"
echo -e "${BLUE}🧪 [04] Executando Suíte de Testes de Integração e E2E (Terratest)${NC}"
echo -e "${BLUE}========================================================================${NC}"
if command -v go &> /dev/null; then
    echo "-> Instalando/organizando dependências Go..."
    cd tests/integration
    go mod tidy
    echo -e "${YELLOW}-> Deseja rodar o Terratest agora? (Atenção: esta etapa pode provisionar infraestrutura efêmera) [yes/No]:${NC}"
    read -r RUN_TEST
    if [ "$RUN_TEST" = "yes" ]; then
        echo "-> Executando Terratest..."
        go test -v -timeout 60m -run TestE2ECluster
    else
        echo "-> Execução do Terratest pulada."
    fi
    cd ../..
else
    echo -e "${YELLOW}ℹ️  Go não está instalado localmente. Pulando suíte Terratest.${NC}"
fi

echo -e "\n${GREEN}========================================================================${NC}"
echo -e "${GREEN}🎉 Execução Local da Pipeline Concluída com Sucesso!${NC}"
echo -e "${GREEN}========================================================================${NC}"
