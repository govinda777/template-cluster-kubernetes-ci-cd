#!/usr/bin/env bash
# ==============================================================================
# Script: scripts/bootstrap-multicloud.sh
# Descrição: Orquestrador unificado de onboarding Day 0 / Pós-Clean-Slate.
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🚀 Automação Unificada de Onboarding Multicloud e OIDC Bootstrap (ADR 0005)${NC}"
echo -e "${BLUE}========================================================================${NC}\n"

# 1. Carregar variáveis de ambiente locais
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

# 2. Validar dependências básicas de CLI
echo -e "${BLUE}[INFO] Validando dependências básicas (aws, gcloud, tofu/terraform, gh)...${NC}"
for CMD in aws gcloud gh; do
    if ! command -v "$CMD" &>/dev/null; then
        echo -e "${RED}[ERRO] Dependência '$CMD' não encontrada no PATH. Instale-a antes de continuar.${NC}"
        exit 1
    fi
done

TOFU_BIN="tofu"
if ! command -v tofu &> /dev/null; then
    TOFU_BIN="terraform"
fi
echo -e "${GREEN}[OK] Dependências validadas. Usando '$TOFU_BIN' para IaC.${NC}\n"

# 3. Validar autenticação AWS
echo -e "${BLUE}[INFO] Validando autenticação na AWS...${NC}"
AWS_ARGS=()
if [ -n "$AWS_PROFILE" ]; then
    AWS_ARGS+=(--profile "$AWS_PROFILE")
fi
if ! aws sts get-caller-identity "${AWS_ARGS[@]}" --region "$AWS_REGION" &>/dev/null; then
    echo -e "${RED}[ERRO] Sessão AWS expirada ou inválida. Execute 'aws sso login' ou reconfigure suas credenciais.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Autenticado na AWS com sucesso!${NC}\n"

# 4. Validar autenticação GCP
echo -e "${BLUE}[INFO] Validando autenticação no GCP...${NC}"
if ! gcloud auth print-access-token &>/dev/null; then
    echo -e "${RED}[ERRO] Sessão GCP expirada ou inválida. Execute 'gcloud auth application-default login' primeiro.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Autenticado no GCP com sucesso!${NC}\n"

# 5. Garantir criação dos backends de estado remoto
echo -e "${BLUE}[INFO] Garantindo criação de Backends de Estado (Day 0 / Pós-Clean-Slate)...${NC}"
chmod +x scripts/setup-backend-aws.sh
chmod +x scripts/setup-backend-gcp.sh

./scripts/setup-backend-aws.sh
./scripts/setup-backend-gcp.sh

# 6. Detectar repositório GitHub
echo -e "${BLUE}[INFO] Detectando repositório GitHub...${NC}"
GITHUB_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
if [ -z "$GITHUB_REPO" ]; then
    GITHUB_REPO=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:\/](.*)\.git/\1/' || true)
fi
if [ -z "$GITHUB_REPO" ]; then
    read -p "Não conseguimos detectar o repositório automaticamente. Digite o formato (owner/repo): " GITHUB_REPO
fi
echo -e "${GREEN}[OK] Repositório detectado: ${YELLOW}$GITHUB_REPO${NC}\n"

# 7. Executar OpenTofu/Terraform Bootstrap (OIDC e WIF)
echo -e "${BLUE}[INFO] Aplicando camada de identidades OIDC/WIF via OpenTofu em terraform/bootstrap...${NC}"

# Exportar variáveis para o OpenTofu
export AWS_PROFILE="$AWS_PROFILE"
export AWS_REGION="$AWS_REGION"

cd terraform/bootstrap
$TOFU_BIN init -upgrade

# Verificar e tratar pool OIDC/WIF existente/soft-deletado no GCP
POOL_ID="github-actions-pool"
PROVIDER_ID="github-actions-provider"

# Obter estado do pool no GCP
POOL_STATE=$(gcloud iam workload-identity-pools describe "$POOL_ID" --location=global --format="value(state)" 2>/dev/null || echo "NOT_EXISTS")
if [ "$POOL_STATE" = "DELETED" ]; then
    echo -e "${YELLOW}[INFO] Detectado Workload Identity Pool soft-deletado no GCP. Restaurando...${NC}"
    gcloud iam workload-identity-pools undelete "$POOL_ID" --location=global >/dev/null 2>&1 || true
    POOL_STATE="ACTIVE"
fi

if [ "$POOL_STATE" = "ACTIVE" ]; then
    echo -e "${YELLOW}[INFO] Pool '$POOL_ID' já existe no GCP. Importando para o estado do OpenTofu...${NC}"
    $TOFU_BIN import \
      -var="aws_region=$AWS_REGION" \
      -var="github_org_repo=$GITHUB_REPO" \
      -var="gcp_project_id=$GCP_PROJECT_ID" \
      -var="gcp_region=$GCP_REGION" \
      google_iam_workload_identity_pool.github "projects/$GCP_PROJECT_ID/locations/global/workloadIdentityPools/$POOL_ID" >/dev/null 2>&1 || true

    # Verificar e tratar o Provider
    PROVIDER_STATE=$(gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" --workload-identity-pool="$POOL_ID" --location=global --format="value(state)" 2>/dev/null || echo "NOT_EXISTS")
    if [ "$PROVIDER_STATE" = "DELETED" ]; then
        echo -e "${YELLOW}[INFO] Detectado Provider soft-deletado no GCP. Restaurando...${NC}"
        gcloud iam workload-identity-pools providers undelete "$PROVIDER_ID" --workload-identity-pool="$POOL_ID" --location=global >/dev/null 2>&1 || true
        PROVIDER_STATE="ACTIVE"
    fi
    if [ "$PROVIDER_STATE" = "ACTIVE" ]; then
        echo -e "${YELLOW}[INFO] Provider '$PROVIDER_ID' já existe no GCP. Importando para o estado do OpenTofu...${NC}"
        $TOFU_BIN import \
          -var="aws_region=$AWS_REGION" \
          -var="github_org_repo=$GITHUB_REPO" \
          -var="gcp_project_id=$GCP_PROJECT_ID" \
          -var="gcp_region=$GCP_REGION" \
          google_iam_workload_identity_pool_provider.github "projects/$GCP_PROJECT_ID/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID" >/dev/null 2>&1 || true
    fi
fi

$TOFU_BIN apply -auto-approve \
  -var="aws_region=$AWS_REGION" \
  -var="github_org_repo=$GITHUB_REPO" \
  -var="gcp_project_id=$GCP_PROJECT_ID" \
  -var="gcp_region=$GCP_REGION"

# Capturar Outputs
AWS_ROLE_DEV=$($TOFU_BIN output -raw github_role_to_assume_dev 2>/dev/null || true)
AWS_ROLE_PROD=$($TOFU_BIN output -raw github_role_to_assume_prod 2>/dev/null || true)
AWS_ROLE_TEST=$($TOFU_BIN output -raw github_role_to_assume_test 2>/dev/null || true)

GCP_WIF_PROVIDER=$($TOFU_BIN output -raw gcp_workload_identity_provider 2>/dev/null || true)
GCP_SA_DEV=$($TOFU_BIN output -raw gcp_service_account_dev 2>/dev/null || true)
GCP_SA_PROD=$($TOFU_BIN output -raw gcp_service_account_prod 2>/dev/null || true)
GCP_SA_TEST=$($TOFU_BIN output -raw gcp_service_account_test 2>/dev/null || true)

cd ../..

# 8. Sincronizar segredos no GitHub
echo -e "\n${BLUE}[INFO] Sincronizando segredos gerados no repositório GitHub...${NC}"
gh secret set AWS_REGION -b "${AWS_REGION}" --repo "${GITHUB_REPO}"
gh secret set AWS_ROLE_TO_ASSUME_DEV -b "${AWS_ROLE_DEV}" --repo "${GITHUB_REPO}"
gh secret set AWS_ROLE_TO_ASSUME_PROD -b "${AWS_ROLE_PROD}" --repo "${GITHUB_REPO}"
gh secret set AWS_ROLE_TO_ASSUME_TEST -b "${AWS_ROLE_TEST}" --repo "${GITHUB_REPO}"

gh secret set GCP_PROJECT_ID -b "${GCP_PROJECT_ID}" --repo "${GITHUB_REPO}"
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER -b "${GCP_WIF_PROVIDER}" --repo "${GITHUB_REPO}"
gh secret set GCP_SA_DEV -b "${GCP_SA_DEV}" --repo "${GITHUB_REPO}"
gh secret set GCP_SA_PROD -b "${GCP_SA_PROD}" --repo "${GITHUB_REPO}"
gh secret set GCP_SA_TEST -b "${GCP_SA_TEST}" --repo "${GITHUB_REPO}"

echo -e "\n${GREEN}========================================================================${NC}"
echo -e "${GREEN}✅ BOOTSTRAP MULTICLOUD CONCLUÍDO COM SUCESSO!${NC}"
echo -e "${GREEN}Todos os recursos de identidade e secrets do GitHub estão sincronizados.${NC}"
echo -e "${GREEN}========================================================================${NC}"
