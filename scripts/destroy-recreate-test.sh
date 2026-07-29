#!/usr/bin/env bash
# ==============================================================================
# Script: scripts/destroy-recreate-test.sh
# Descrição: Script de teste integrado para destruição total e reconstrução
#            do ambiente multi-cloud (AWS e GCP).
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🔥 Teste Integrado de Destruição e Reconstrução (Clean Slate)${NC}"
echo -e "${BLUE}========================================================================${NC}\n"

# 1. Carregar variáveis de ambiente
if [ -f ".aws_profile_env" ]; then
    source .aws_profile_env
fi
if [ -f ".gcp_profile_env" ]; then
    source .gcp_profile_env
fi

AWS_PROFILE="${AWS_PROFILE}"
AWS_REGION="${AWS_REGION:-us-east-1}"
GCP_PROJECT_ID="${GCP_PROJECT_ID}"
GCP_REGION="${GCP_REGION:-us-central1}"

# Detectar IaC
TOFU_BIN="tofu"
if ! command -v tofu &> /dev/null; then
    TOFU_BIN="terraform"
fi

# 2. Pré-limpeza do Kubernetes (Para evitar travamento de ELBs/VPC)
echo -e "${BLUE}[INFO] 1. Tentando limpar recursos do Kubernetes (Services/Gateways/Routes)...${NC}"

clean_k8s_resources() {
    local context=$1
    local cluster=$2
    local region=$3
    echo -e "${YELLOW}  -> Limpando recursos no cluster $cluster ($region)...${NC}"
    
    # Atualizar kubeconfig para garantir contexto
    if [ "$context" = "aws" ]; then
        aws eks update-kubeconfig --name "$cluster" --region "$region" ${AWS_PROFILE:+--profile "$AWS_PROFILE"} &>/dev/null || true
    elif [ "$context" = "gcp" ]; then
        gcloud container clusters get-credentials "$cluster" --region "$region" --project "$GCP_PROJECT_ID" &>/dev/null || true
    fi

    # Deletar recursos que criam LoadBalancers físicos na nuvem
    if kubectl get namespaces &>/dev/null; then
        kubectl delete gateway --all --all-namespaces --timeout=60s || true
        kubectl delete httproute --all --all-namespaces --timeout=30s || true
        kubectl delete svc --all --all-namespaces --field-selector metadata.name!=kubernetes --timeout=60s || true
        echo -e "${GREEN}  [OK] Recursos Kubernetes do cluster $cluster limpos.${NC}"
    else
        echo -e "${YELLOW}  [WARN] Não foi possível conectar ao cluster ou o cluster não existe.${NC}"
    fi
}

# Limpar EKS Dev
clean_k8s_resources "aws" "template-eks-cluster-dev" "$AWS_REGION"
# Limpar GKE Dev se existir
clean_k8s_resources "gcp" "template-gke-cluster-dev" "$GCP_REGION"

# 3. Destruir os ambientes live (Dev e Prod)
echo -e "\n${BLUE}[INFO] 2. Destruindo Ambiente de Desenvolvimento (Dev)...${NC}"
cd terraform/live/dev
$TOFU_BIN init -upgrade
# Passar variáveis reais para destruição bem-sucedida do GCP GKE
$TOFU_BIN destroy -auto-approve \
  -var="aws_region=$AWS_REGION" \
  -var="gcp_project_id=$GCP_PROJECT_ID" \
  -var="gcp_region=$GCP_REGION" \
  -var="enable_gke=true" || {
    echo -e "${YELLOW}[WARN] Primeira tentativa de destroy falhou ou GKE não estava ativo. Forçando com enable_gke=false...${NC}"
    $TOFU_BIN destroy -auto-approve \
      -var="aws_region=$AWS_REGION" \
      -var="gcp_project_id=$GCP_PROJECT_ID" \
      -var="gcp_region=$GCP_REGION" \
      -var="enable_gke=false"
}
cd ../../..

echo -e "\n${BLUE}[INFO] 3. Destruindo Ambiente de Produção (Prod)...${NC}"
cd terraform/live/prod
$TOFU_BIN init -upgrade
$TOFU_BIN destroy -auto-approve \
  -var="aws_region=$AWS_REGION" \
  -var="gcp_project_id=$GCP_PROJECT_ID" \
  -var="gcp_region=$GCP_REGION" || true
cd ../../..

# 4. Destruir o Bootstrap (OIDC e WIF)
echo -e "\n${BLUE}[INFO] 4. Destruindo Camada de Bootstrap...${NC}"
GITHUB_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:\/](.*)\.git/\1/' || echo "")
cd terraform/bootstrap
$TOFU_BIN init -upgrade
$TOFU_BIN destroy -auto-approve \
  -var="aws_region=$AWS_REGION" \
  -var="github_org_repo=$GITHUB_REPO" \
  -var="gcp_project_id=$GCP_PROJECT_ID" \
  -var="gcp_region=$GCP_REGION"
cd ../..

echo -e "\n${GREEN}=== DESTRUIÇÃO TOTAL CONCLUÍDA COM SUCESSO ===${NC}"

# 5. RECONSTRUÇÃO: Executar Onboarding Completo (Day 0)
echo -e "\n${BLUE}[INFO] 5. Iniciando Processo de Reconstrução Completa...${NC}"

# Executa o bootstrap multicloud para recriar identidades, backends e atualizar secrets no GitHub
chmod +x scripts/bootstrap-multicloud.sh
./scripts/bootstrap-multicloud.sh

# Re-aplicar Dev
echo -e "\n${BLUE}[INFO] 6. Provisionando ambiente de Desenvolvimento (Dev)...${NC}"
cd terraform/live/dev
$TOFU_BIN init -upgrade
$TOFU_BIN apply -auto-approve \
  -var="aws_region=$AWS_REGION" \
  -var="gcp_project_id=$GCP_PROJECT_ID" \
  -var="gcp_region=$GCP_REGION" \
  -var="enable_gke=true"
cd ../../..

echo -e "\n${GREEN}========================================================================${NC}"
echo -e "${GREEN}🎉 TESTE INTEGRADO DE DESTRUIÇÃO E RECONSTRUÇÃO FINALIZADO COM SUCESSO!${NC}"
echo -e "${GREEN}========================================================================${NC}"
