#!/usr/bin/env bash
# ==============================================================================
# Script: scripts/configure-kubeconfig.sh
# Descrição: Validação de perfil AWS, configuração de kubeconfig e teste de conexão.
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações padrões (pode herdar do ambiente)
CLUSTER_NAME="${CLUSTER_NAME:-template-eks-cluster-dev}"
REGION="${AWS_REGION:-us-east-1}"
PROFILE="${AWS_PROFILE}"

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}        Configuração Automática do Kubeconfig${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

# 1. Verificar dependências
if ! command -v aws &>/dev/null; then
    echo -e "${RED}[ERRO] AWS CLI não foi encontrada no PATH. Instale-a antes de continuar.${NC}"
    exit 1
fi

if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}[ERRO] kubectl não foi encontrado no PATH. Instale-o antes de continuar.${NC}"
    exit 1
fi

# 2. Validar autenticação e perfil ativo
echo -e "${BLUE}[INFO] Validando identidade ativa no AWS IAM...${NC}"
AWS_ARGS=()
if [ -n "$PROFILE" ]; then
    AWS_ARGS+=(--profile "$PROFILE")
    echo -e "  -> Usando Perfil AWS: ${YELLOW}$PROFILE${NC}"
fi

if ! CALLER_IDENTITY=$(aws sts get-caller-identity "${AWS_ARGS[@]}" --region "$REGION" 2>/dev/null); then
    echo -e "${RED}[ERRO] Não foi possível autenticar na AWS com o perfil atual.${NC}"
    echo -e "${YELLOW}[DICA] Execute 'make config aws' ou valide suas credenciais SSO executando: aws sso login --profile ${PROFILE:-default}${NC}"
    exit 1
fi

# Resgata o ARN e Conta usando queries nativas e seguras da AWS CLI (evitando dependências de grep/jq)
ARN=$(aws sts get-caller-identity --query "Arn" --output text "${AWS_ARGS[@]}" --region "$REGION" 2>/dev/null || true)
ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text "${AWS_ARGS[@]}" --region "$REGION" 2>/dev/null || true)

echo -e "${GREEN}[OK] Identidade AWS Confirmada!${NC}"
echo -e "  - Conta AWS: ${YELLOW}$ACCOUNT${NC}"
echo -e "  - IAM Principal ARN: ${YELLOW}$ARN${NC}\n"

# 3. Atualizar kubeconfig
echo -e "${BLUE}[INFO] Atualizando arquivo ~/.kube/config para o cluster: ${YELLOW}$CLUSTER_NAME${NC}...${NC}"
if ! aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" "${AWS_ARGS[@]}" &>/dev/null; then
    echo -e "${RED}[ERRO] Falha ao atualizar o kubeconfig via AWS CLI.${NC}"
    echo -e "${YELLOW}[DICA] Verifique se o nome do cluster '$CLUSTER_NAME' e a região '$REGION' estão corretos na sua conta.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Arquivo Kubeconfig atualizado com sucesso!${NC}\n"

# 4. Validar conexão com o cluster tratando erros de RBAC
echo -e "${BLUE}[INFO] Testando comunicação ativa com o cluster via 'kubectl'...${NC}"
KUBECTL_ERROR=$(mktemp)

if kubectl get nodes &>/dev/null 2>"$KUBECTL_ERROR"; then
    echo -e "${GREEN}=====================================================${NC}"
    echo -e "${GREEN}[SUCESSO] Conexão com o cluster Kubernetes estabelecida!${NC}"
    echo -e "${GREEN}Você possui acesso de leitura completo e seu contexto local está pronto.${NC}"
    echo -e "${GREEN}=====================================================${NC}"
    rm -f "$KUBECTL_ERROR"
    exit 0
else
    ERROR_MSG=$(cat "$KUBECTL_ERROR")
    rm -f "$KUBECTL_ERROR"

    echo -e "${RED}[FALHA] Não foi possível obter resposta autorizada do cluster Kubernetes.${NC}"

    if [[ "$ERROR_MSG" == *"Unauthorized"* ]] || [[ "$ERROR_MSG" == *"You must be logged in to the server"* ]] || [[ "$ERROR_MSG" == *"Access Denied"* ]]; then
        echo -e "\n${RED}-----------------------------------------------------${NC}"
        echo -e "${RED}ERRO DETECTADO: Falha de Autenticação / RBAC do EKS${NC}"
        echo -e "${RED}-----------------------------------------------------${NC}"
        echo -e "${YELLOW}Detalhes Técnicos do kubectl:${NC}\n$ERROR_MSG"
        echo -e "\n${YELLOW}CAUSA PROVÁVEL:${NC}"
        echo -e "Sua entidade IAM principal (${ARN}) foi autenticada pela AWS, mas não possui permissões associadas dentro do cluster Kubernetes (via EKS Access Entries ou aws-auth ConfigMap)."
        echo -e "\n${BLUE}COMO CORRIGIR:${NC}"
        echo -e "Solicite ao administrador do Cloud que execute os seguintes comandos na conta para registrar seu acesso:"
        echo -e "  1. aws eks create-access-entry --cluster-name $CLUSTER_NAME --principal-arn $ARN"
        echo -e "  2. aws eks associate-access-policy --cluster-name $CLUSTER_NAME --principal-arn $ARN --policy-arn arn:aws:eks:aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster"
    else
        echo -e "${YELLOW}[ERRO DESCONHECIDO] Verifique sua conexão de rede ou VPN:${NC}\n$ERROR_MSG"
    fi
    exit 1
fi
