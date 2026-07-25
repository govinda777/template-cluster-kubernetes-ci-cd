#!/usr/bin/env bash
set -eo pipefail

# Cores para formatação de logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}  Configuração e Autenticação - AWS CLI / AWS SSO   ${NC}"
echo -e "${CYAN}=====================================================${NC}"

# 1. Validação de Dependências
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI não foi encontrado instalado no sistema."
    log_info "Por favor, instale o AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi
log_success "AWS CLI detectado: $(aws --version | head -n 1)"

# 2. Configuração do Perfil e Login SSO
read -p "Deseja realizar autenticação via AWS SSO? [y/N]: " USE_SSO
USE_SSO=${USE_SSO:-N}

read -p "Informe o nome do AWS Profile [default]: " AWS_PROF
AWS_PROF=${AWS_PROF:-default}

export AWS_PROFILE="$AWS_PROF"
log_info "Perfil selecionado: AWS_PROFILE='$AWS_PROFILE'"

if [[ "$USE_SSO" =~ ^[Yy]$ ]]; then
    log_info "Iniciando fluxo de autenticação AWS SSO..."
    aws sso login --profile "$AWS_PROFILE"
fi

# 3. Teste e Validação da Identidade
log_info "Validando credenciais ativas na AWS via sts:GetCallerIdentity..."

# Mockamos ou testamos a identidade localmente
if IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null); then
    ACCOUNT_ID=$(echo "$IDENTITY" | grep -o '"Account": "[^"]*' | cut -d'"' -f4)
    ARN=$(echo "$IDENTITY" | grep -o '"Arn": "[^"]*' | cut -d'"' -f4)
    USER_ID=$(echo "$IDENTITY" | grep -o '"UserId": "[^"]*' | cut -d'"' -f4)
    REGION=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "us-east-1")

    echo ""
    log_success "Autenticação AWS validada com sucesso!"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "  ${YELLOW}Conta AWS (Account ID):${NC} $ACCOUNT_ID"
    echo -e "  ${YELLOW}ARN da Identidade:${NC}     $ARN"
    echo -e "  ${YELLOW}User ID / Role:${NC}        $USER_ID"
    echo -e "  ${YELLOW}Região Ativa:${NC}          $REGION"
    echo -e "  ${YELLOW}AWS Profile:${NC}           $AWS_PROFILE"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
else
    log_error "Falha na autenticação com a AWS para o perfil '$AWS_PROFILE'."
    log_warning "Certifique-se de que o SSO foi concluído ou que as credenciais em ~/.aws/credentials são válidas."
    exit 1
fi
