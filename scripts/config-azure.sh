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
echo -e "${CYAN}  Configuração e Autenticação - Microsoft Azure CLI  ${NC}"
echo -e "${CYAN}=====================================================${NC}"

# 1. Validação de Dependências
if ! command -v az &> /dev/null; then
    log_error "Azure CLI (az) não foi encontrada instalada no sistema."
    log_info "Por favor, instale a Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi
log_success "Azure CLI detectada."

# 2. Autenticação Interativa via Browser/Device
log_info "Iniciando autenticação no Azure (az login)..."
az login --output table

# 3. Listagem e Seleção da Subscription
log_info "Obtendo lista de Subscriptions disponíveis:"
az account list --output table

echo ""
read -p "Informe o Nome ou ID da Subscription que deseja definir como ativa: " SUB_NAME_OR_ID

if [ -z "$SUB_NAME_OR_ID" ]; then
    log_warning "Nenhuma Subscription digitada. Mantendo a Subscription marcada como Padrão (Default)."
else
    log_info "Ativando a Subscription '$SUB_NAME_OR_ID'..."
    az account set --subscription "$SUB_NAME_OR_ID"
fi

# 4. Validação e Exibição do Status da Conta
SHOW_ACCOUNT=$(az account show --output json)
ACTIVE_SUB_NAME=$(echo "$SHOW_ACCOUNT" | grep -o '"name": "[^"]*' | head -n 1 | cut -d'"' -f4)
ACTIVE_SUB_ID=$(echo "$SHOW_ACCOUNT" | grep -o '"id": "[^"]*' | head -n 1 | cut -d'"' -f4)
TENANT_ID=$(echo "$SHOW_ACCOUNT" | grep -o '"tenantId": "[^"]*' | head -n 1 | cut -d'"' -f4)
USER_NAME=$(echo "$SHOW_ACCOUNT" | grep -o '"name": "[^"]*' | tail -n 1 | cut -d'"' -f4)

echo ""
log_success "Autenticação na Microsoft Azure realizada com sucesso!"
echo -e "${CYAN}-----------------------------------------------------${NC}"
echo -e "  ${YELLOW}Usuário / Identidade:${NC}  $USER_NAME"
echo -e "  ${YELLOW}Subscription Ativa:${NC}   $ACTIVE_SUB_NAME"
echo -e "  ${YELLOW}Subscription ID:${NC}      $ACTIVE_SUB_ID"
echo -e "  ${YELLOW}Tenant ID:${NC}            $TENANT_ID"
echo -e "${CYAN}-----------------------------------------------------${NC}"
