#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🔧 Setup de Backend Terraform (S3 Buckets & DynamoDB Tables)${NC}"
echo -e "${BLUE}========================================================================${NC}\n"

# Load AWS profile from environment file
if [ -f ".aws_profile_env" ]; then
    source .aws_profile_env
    echo -e "${GREEN}[OK] Perfil AWS carregado: ${YELLOW}$AWS_PROFILE${NC}"
    echo -e "${GREEN}[OK] Região AWS: ${YELLOW}$AWS_REGION${NC}\n"
else
    echo -e "${RED}[ERROR] Arquivo .aws_profile_env não encontrado.${NC}"
    echo -e "${YELLOW}[INFO] Execute 'make config aws' primeiro para configurar a autenticação.${NC}"
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

# Export AWS credentials for OpenTofu
export AWS_PROFILE
export AWS_REGION

echo -e "${BLUE}[INFO] Inicializando Terraform/OpenTofu...${NC}"
$TOFU_BIN init

echo -e "\n${BLUE}[INFO] Planejando criação dos recursos de backend...${NC}"
$TOFU_BIN plan -out=tfplan

echo -e "\n${YELLOW}Deseja aplicar o plano para criar os buckets S3 e tabelas DynamoDB? [yes/No]:${NC}"
read -r CONFIRM
if [ "$CONFIRM" = "yes" ]; then
    echo -e "${BLUE}[INFO] Aplicando recursos...${NC}"
    $TOFU_BIN apply -auto-approve tfplan
    
    echo -e "\n${GREEN}========================================================================${NC}"
    echo -e "${GREEN}✅ Backend configurado com sucesso!${NC}"
    echo -e "${GREEN}========================================================================${NC}"
    echo -e "${GREEN}Buckets S3 criados:${NC}"
    echo -e "  - template-cluster-k8s-terraform-state-dev"
    echo -e "  - template-cluster-k8s-terraform-state-prod"
    echo -e "${GREEN}Tabelas DynamoDB criadas:${NC}"
    echo -e "  - template-cluster-k8s-tflocks-dev"
    echo -e "  - template-cluster-k8s-tflocks-prod"
    echo -e "${GREEN}========================================================================${NC}"
else
    echo -e "${YELLOW}[INFO] Aplicação cancelada pelo usuário.${NC}"
    exit 0
fi

cd ../..
