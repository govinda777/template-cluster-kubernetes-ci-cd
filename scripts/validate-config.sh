#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🔍 Validação de Configuração Pré-Deployment${NC}"
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

# 1. Check EKS available versions
echo -e "${BLUE}[INFO] Verificando versões disponíveis do EKS na região $AWS_REGION...${NC}"
EKS_VERSIONS=$(aws eks describe-cluster-versions --region "$AWS_REGION" --profile "$AWS_PROFILE" --output json 2>/dev/null || true)

if [ -z "$EKS_VERSIONS" ]; then
    echo -e "${RED}[ERROR] Não foi possível obter versões do EKS. Verifique suas credenciais.${NC}"
    exit 1
fi

AVAILABLE_VERSIONS=$(echo "$EKS_VERSIONS" | jq -r '.clusterVersions[].clusterVersion' | sort -V)
DEFAULT_VERSION=$(echo "$EKS_VERSIONS" | jq -r '.clusterVersions[] | select(.defaultVersion == true) | .clusterVersion')

echo -e "${GREEN}[OK] Versões disponíveis:${NC}"
echo "$AVAILABLE_VERSIONS" | while read -r version; do
    if [ "$version" = "$DEFAULT_VERSION" ]; then
        echo -e "  ${GREEN}✓ $version (padrão)${NC}"
    else
        echo -e "  - $version"
    fi
done

# 2. Check configured version in Terraform
echo -e "\n${BLUE}[INFO] Verificando versão configurada no módulo EKS...${NC}"
CONFIGURED_VERSION=$(cat terraform/modules/eks/variables.tf | grep -A 2 'kubernetes_version' | grep 'default' | sed 's/.*default.*=.*"\(.*\)".*/\1/' || echo "")

if [ -z "$CONFIGURED_VERSION" ]; then
    echo -e "${YELLOW}[WARN] Não foi possível detectar a versão configurada automaticamente.${NC}"
    echo -e "${YELLOW}[INFO] Verifique manualmente se a versão em terraform/modules/eks/variables.tf está disponível acima.${NC}"
else
    echo -e "${BLUE}Versão configurada: ${YELLOW}$CONFIGURED_VERSION${NC}"
    
    # Check if configured version is available
    if echo "$AVAILABLE_VERSIONS" | grep -q "^$CONFIGURED_VERSION$"; then
        echo -e "${GREEN}[OK] Versão $CONFIGURED_VERSION está disponível na região $AWS_REGION${NC}"
    else
        echo -e "${RED}[ERROR] Versão $CONFIGURED_VERSION NÃO está disponível na região $AWS_REGION${NC}"
        echo -e "${YELLOW}[INFO] Versões disponíveis:${NC}"
        echo "$AVAILABLE_VERSIONS" | sed 's/^/  /'
        echo -e "\n${YELLOW}[SUGESTÃO] Atualize a versão em terraform/modules/eks/variables.tf para: $DEFAULT_VERSION${NC}"
        exit 1
    fi
fi

# 3. Check S3 backend buckets
echo -e "\n${BLUE}[INFO] Verificando buckets S3 de backend...${NC}"
BUCKETS=("template-cluster-k8s-terraform-state-dev" "template-cluster-k8s-terraform-state-prod")
ALL_BUCKETS_EXIST=true

for bucket in "${BUCKETS[@]}"; do
    if aws s3 ls "s3://$bucket" --region "$AWS_REGION" --profile "$AWS_PROFILE" &>/dev/null; then
        echo -e "${GREEN}[OK] Bucket $bucket existe${NC}"
    else
        echo -e "${RED}[ERROR] Bucket $bucket NÃO existe${NC}"
        ALL_BUCKETS_EXIST=false
    fi
done

if [ "$ALL_BUCKETS_EXIST" = false ]; then
    echo -e "\n${YELLOW}[INFO] Execute 'bash scripts/setup-backend.sh' para criar os buckets S3 necessários${NC}"
    exit 1
fi

# 4. Check DynamoDB tables
echo -e "\n${BLUE}[INFO] Verificando tabelas DynamoDB de locking...${NC}"
TABLES=("template-cluster-k8s-tflocks-dev" "template-cluster-k8s-tflocks-prod")
ALL_TABLES_EXIST=true

for table in "${TABLES[@]}"; do
    if aws dynamodb describe-table --table-name "$table" --region "$AWS_REGION" --profile "$AWS_PROFILE" &>/dev/null; then
        echo -e "${GREEN}[OK] Tabela $table existe${NC}"
    else
        echo -e "${RED}[ERROR] Tabela $table NÃO existe${NC}"
        ALL_TABLES_EXIST=false
    fi
done

if [ "$ALL_TABLES_EXIST" = false ]; then
    echo -e "\n${YELLOW}[INFO] Execute 'bash scripts/setup-backend.sh' para criar as tabelas DynamoDB necessárias${NC}"
    exit 1
fi

echo -e "\n${GREEN}========================================================================${NC}"
echo -e "${GREEN}✅ Todas as validações passaram com sucesso!${NC}"
echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}A configuração está pronta para execução da pipeline.${NC}"
