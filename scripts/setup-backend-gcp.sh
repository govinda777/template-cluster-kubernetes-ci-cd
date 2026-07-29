#!/usr/bin/env bash
# ==============================================================================
# Script: scripts/setup-backend-gcp.sh
# Descrição: Criação idempotente dos recursos de backend do Terraform no GCP.
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Garantindo Backend de Estado GCP (GCS Buckets) ===${NC}"

if [ -f ".gcp_profile_env" ]; then
    source .gcp_profile_env
fi

GCP_PROJECT_ID="${GCP_PROJECT_ID}"
GCP_REGION="${GCP_REGION:-us-central1}"

if [ -z "$GCP_PROJECT_ID" ]; then
    echo -e "${YELLOW}[WARN] GCP_PROJECT_ID não configurado. Tentando obter do gcloud CLI...${NC}"
    GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
fi

if [ -z "$GCP_PROJECT_ID" ]; then
    echo -e "${RED}[ERRO] GCP_PROJECT_ID não pôde ser detectado. Execute 'make config gcp' primeiro.${NC}"
    exit 1
fi

BUCKETS=("template-cluster-k8s-terraform-state-dev" "template-cluster-k8s-terraform-state-prod")

# Garantir Buckets GCS
for BUCKET in "${BUCKETS[@]}"; do
    if gcloud storage buckets describe "gs://$BUCKET" &>/dev/null; then
        echo -e "${GREEN}[OK] Bucket GCS 'gs://$BUCKET' já existe.${NC}"
    else
        echo -e "${YELLOW}[INFO] Criando Bucket GCS 'gs://$BUCKET'...${NC}"
        gcloud storage buckets create "gs://$BUCKET" \
            --project="$GCP_PROJECT_ID" \
            --location="US" \
            --uniform-bucket-level-access

        # Habilitar versionamento
        gcloud storage buckets update "gs://$BUCKET" --versioning

        # Prevenção de Acesso Público
        gcloud storage buckets update "gs://$BUCKET" --public-access-prevention

        echo -e "${GREEN}[OK] Bucket GCS 'gs://$BUCKET' criado e configurado com sucesso!${NC}"
    fi
done

echo -e "${GREEN}=== Setup de Backend GCP Concluído! ===${NC}\n"
