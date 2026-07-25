#!/usr/bin/env bash
set -eo pipefail

# Cores para formatação de logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}  Configuração e Autenticação - Google Cloud (GCP)  ${NC}"
echo -e "${CYAN}=====================================================${NC}"

# 1. Validação de Dependências
if ! command -v gcloud &> /dev/null; then
    log_error "Google Cloud SDK (gcloud) não foi encontrado instalado no sistema."
    log_info "Por favor, instale a gcloud CLI: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
log_success "gcloud SDK detectado: $(gcloud --version | head -n 1)"

# 2. Login de Usuário na CLI do gcloud
log_info "Iniciando autenticação do usuário no Google Cloud CLI (gcloud auth login)..."
gcloud auth login

# 3. Login de Credenciais Padrão de Aplicação (ADC para Terraform/IaC)
log_info "Iniciando autenticação Application Default Credentials para ferramentas IaC (Terraform)..."
gcloud auth application-default login

# 4. Seleção e Configuração do Project ID
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -n "$CURRENT_PROJECT" ]; then
    log_info "Projeto GCP atualmente ativo: $CURRENT_PROJECT"
fi

read -p "Informe o GCP Project ID que deseja ativar: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    if [ -n "$CURRENT_PROJECT" ]; then
        PROJECT_ID="$CURRENT_PROJECT"
    else
        log_error "O Project ID do GCP não pode ser vazio."
        exit 1
    fi
fi

log_info "Definindo o projeto ativo para '$PROJECT_ID'..."
gcloud config set project "$PROJECT_ID"

# 5. Exibição do Resumo de Autenticação
ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "Não identificada")

echo ""
log_success "Autenticação no Google Cloud concluída com sucesso!"
echo -e "${CYAN}-----------------------------------------------------${NC}"
echo -e "  ${YELLOW}Conta GCP Ativa:${NC}   $ACTIVE_ACCOUNT"
echo -e "  ${YELLOW}Projeto GCP Ativo:${NC} $PROJECT_ID"
echo -e "${CYAN}-----------------------------------------------------${NC}"
