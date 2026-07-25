#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🔧 Setup de Backend Terraform (S3 Buckets, DynamoDB Tables & GCS Buckets)${NC}"
echo -e "${BLUE}========================================================================${NC}\n"

# Load AWS profile if available
HAS_AWS=false
if [ -f ".aws_profile_env" ]; then
    source .aws_profile_env
    echo -e "${GREEN}[OK] Perfil AWS carregado: ${YELLOW}$AWS_PROFILE${NC}"
    echo -e "${GREEN}[OK] Região AWS: ${YELLOW}$AWS_REGION${NC}\n"
    HAS_AWS=true
else
    echo -e "${YELLOW}[INFO] Arquivo .aws_profile_env não encontrado. Ignorando setup AWS por enquanto.${NC}"
fi

# Load GCP profile if available
HAS_GCP=false
if [ -f ".gcp_profile_env" ]; then
    source .gcp_profile_env
    echo -e "${GREEN}[OK] Projeto GCP carregado: ${YELLOW}$GCP_PROJECT_ID${NC}"
    echo -e "${GREEN}[OK] Região GCP: ${YELLOW}$GCP_REGION${NC}\n"
    HAS_GCP=true
else
    echo -e "${YELLOW}[INFO] Arquivo .gcp_profile_env não encontrado. Ignorando setup GCP por enquanto.${NC}"
fi

if [ "$HAS_AWS" = false ] && [ "$HAS_GCP" = false ]; then
    echo -e "${RED}[ERROR] Nenhum arquivo de perfil (.aws_profile_env ou .gcp_profile_env) foi encontrado.${NC}"
    echo -e "${YELLOW}[INFO] Execute 'make config aws' ou 'make config gcp' primeiro para configurar a autenticação.${NC}"
    exit 1
fi

# Detect Terraform or OpenTofu
TOFU_BIN="tofu"
if ! command -v tofu &> /dev/null; then
    TOFU_BIN="terraform"
fi
echo -e "${BLUE}[INFO] Usando: ${YELLOW}$TOFU_BIN${NC}\n"

# Navigate to backend directory
cd terraform/backend

# Export AWS credentials for OpenTofu if available
if [ "$HAS_AWS" = true ]; then
    export AWS_PROFILE
    export AWS_REGION
fi

# Export GCP variables for OpenTofu if available
GCP_VARS=""
if [ "$HAS_GCP" = true ]; then
    GCP_VARS="-var=\"gcp_project_id=$GCP_PROJECT_ID\" -var=\"gcp_region=$GCP_REGION\""
fi

echo -e "${BLUE}[INFO] Inicializando Terraform/OpenTofu...${NC}"
$TOFU_BIN init

echo -e "\n${BLUE}[INFO] Planejando criação dos recursos de backend...${NC}"
eval "$TOFU_BIN plan $GCP_VARS -out=tfplan"

echo -e "\n${YELLOW}Deseja aplicar o plano para criar os recursos de backend? [yes/No]:${NC}"
read -r CONFIRM
if [ "$CONFIRM" = "yes" ]; then
    echo -e "${BLUE}[INFO] Aplicando recursos...${NC}"
    $TOFU_BIN apply -auto-approve tfplan
    
    echo -e "\n${GREEN}========================================================================${NC}"
    echo -e "${GREEN}✅ Backend configurado com sucesso!${NC}"
    echo -e "${GREEN}========================================================================${NC}"
    if [ "$HAS_AWS" = true ]; then
        echo -e "${GREEN}Buckets S3 criados:${NC}"
        echo -e "  - template-cluster-k8s-terraform-state-dev"
        echo -e "  - template-cluster-k8s-terraform-state-prod"
        echo -e "${GREEN}Tabelas DynamoDB criadas:${NC}"
        echo -e "  - template-cluster-k8s-tflocks-dev"
        echo -e "  - template-cluster-k8s-tflocks-prod"
    fi
    if [ "$HAS_GCP" = true ]; then
        echo -e "${GREEN}Buckets GCS criados:${NC}"
        echo -e "  - template-cluster-k8s-terraform-state-dev"
        echo -e "  - template-cluster-k8s-terraform-state-prod"
    fi
    echo -e "${GREEN}========================================================================${NC}"
else
    echo -e "${YELLOW}[INFO] Aplicação cancelada pelo usuário.${NC}"
    exit 0
fi

cd ../..
