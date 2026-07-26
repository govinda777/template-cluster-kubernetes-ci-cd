#!/usr/bin/env bash
# ==============================================================================
# Script: scripts/setup-backend-aws.sh
# Descrição: Criação idempotente dos recursos de backend do Terraform na AWS.
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Garantindo Backend de Estado AWS (S3 & DynamoDB) ===${NC}"

# Unset de credenciais estáticas
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

if [ -f ".aws_profile_env" ]; then
    source .aws_profile_env
fi

AWS_PROFILE="${AWS_PROFILE}"
AWS_REGION="${AWS_REGION:-us-east-1}"

AWS_ARGS=()
if [ -n "$PROFILE" ]; then
    AWS_ARGS+=(--profile "$PROFILE")
elif [ -n "$AWS_PROFILE" ]; then
    AWS_ARGS+=(--profile "$AWS_PROFILE")
fi

# Validar conexão AWS
if ! aws sts get-caller-identity "${AWS_ARGS[@]}" --region "$AWS_REGION" &>/dev/null; then
    echo -e "${RED}[ERRO] Não autenticado na AWS. Execute 'aws sso login' ou configure suas credenciais primeiro.${NC}"
    exit 1
fi

BUCKETS=("template-cluster-k8s-terraform-state-dev" "template-cluster-k8s-terraform-state-prod")
TABLES=("template-cluster-k8s-tflocks-dev" "template-cluster-k8s-tflocks-prod")

# 1. Garantir Buckets S3
for BUCKET in "${BUCKETS[@]}"; do
    if aws s3api head-bucket --bucket "$BUCKET" "${AWS_ARGS[@]}" --region "$AWS_REGION" 2>/dev/null; then
        echo -e "${GREEN}[OK] Bucket S3 '$BUCKET' já existe.${NC}"
    else
        echo -e "${YELLOW}[INFO] Criando Bucket S3 '$BUCKET'...${NC}"
        # Se for us-east-1, LocationConstraint não pode ser especificado
        if [ "$AWS_REGION" = "us-east-1" ]; then
            aws s3api create-bucket --bucket "$BUCKET" "${AWS_ARGS[@]}" --region "$AWS_REGION" > /dev/null
        else
            aws s3api create-bucket --bucket "$BUCKET" --create-bucket-configuration LocationConstraint="$AWS_REGION" "${AWS_ARGS[@]}" --region "$AWS_REGION" > /dev/null
        fi

        # Habilitar Versionamento
        aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled "${AWS_ARGS[@]}" --region "$AWS_REGION"

        # Bloquear Acesso Público
        aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" "${AWS_ARGS[@]}" --region "$AWS_REGION"

        # Criptografia por Padrão
        aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' "${AWS_ARGS[@]}" --region "$AWS_REGION"

        echo -e "${GREEN}[OK] Bucket S3 '$BUCKET' criado e configurado com sucesso!${NC}"
    fi
done

# 2. Garantir Tabelas DynamoDB
for TABLE in "${TABLES[@]}"; do
    if aws dynamodb describe-table --table-name "$TABLE" "${AWS_ARGS[@]}" --region "$AWS_REGION" 2>/dev/null; then
        echo -e "${GREEN}[OK] Tabela DynamoDB '$TABLE' já existe.${NC}"
    else
        echo -e "${YELLOW}[INFO] Criando Tabela DynamoDB '$TABLE'...${NC}"
        aws dynamodb create-table \
            --table-name "$TABLE" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --sse-specification Enabled=true \
            "${AWS_ARGS[@]}" --region "$AWS_REGION" > /dev/null

        echo -e "${GREEN}[OK] Tabela DynamoDB '$TABLE' criada com sucesso!${NC}"
    fi
done

echo -e "${GREEN}=== Setup de Backend AWS Concluído! ===${NC}\n"
