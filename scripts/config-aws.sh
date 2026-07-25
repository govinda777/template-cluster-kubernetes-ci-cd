#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}   Configuração e Autenticação Automatizada - AWS CLI${NC}"
echo -e "${CYAN}=====================================================${NC}\n"

# 1. Verifica se o AWS CLI já está instalado
if command -v aws &> /dev/null; then
    log_success "AWS CLI já está instalado: $(aws --version | head -n 1)"
else
    log_warning "AWS CLI não foi encontrado. Iniciando instalação automática..."

    OS="$(uname -s)"
    case "${OS}" in
        Darwin*)
            log_info "Sistema operacional detectado: macOS"
            if command -v brew &> /dev/null; then
                log_info "Instalando AWS CLI via Homebrew..."
                brew install awscli
            else
                log_info "Homebrew não encontrado. Baixando instalador oficial .pkg da AWS..."
                curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "/tmp/AWSCLIV2.pkg"
                sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
                rm -f /tmp/AWSCLIV2.pkg
            fi
            ;;
        Linux*)
            log_info "Sistema operacional detectado: Linux"
            if ! command -v unzip &> /dev/null; then
                log_warning "Instalando dependência (unzip)..."
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update && sudo apt-get install -y unzip curl
                elif command -v dnf &> /dev/null; then
                    sudo dnf install -y unzip curl
                elif command -v yum &> /dev/null; then
                    sudo yum install -y unzip curl
                fi
            fi

            ARCH="$(uname -m)"
            if [ "$ARCH" = "aarch64" ]; then
                CLI_ZIP="awscli-exe-linux-aarch64.zip"
            else
                CLI_ZIP="awscli-exe-linux-x86_64.zip"
            fi

            log_info "Baixando e instalando AWS CLI v2 para ${ARCH}..."
            curl "https://awscli.amazonaws.com/${CLI_ZIP}" -o "/tmp/awscliv2.zip"
            unzip -q /tmp/awscliv2.zip -d /tmp/
            sudo /tmp/aws/install --update
            rm -rf /tmp/aws /tmp/awscliv2.zip
            ;;
        *)
            log_error "Sistema operacional ${OS} não suportado para instalação automática."
            echo "Por favor, instale o AWS CLI manualmente: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
            exit 1
            ;;
    esac

    # Garantir que o binário esteja no PATH da sessão atual se necessário
    export PATH="/usr/local/bin:$PATH"

    if command -v aws &> /dev/null; then
        log_success "AWS CLI instalado com sucesso! ($(aws --version | head -n 1))"
    else
        log_error "Falha ao verificar a instalação do AWS CLI."
        exit 1
    fi
fi

# Seleção do Perfil AWS (AWS_PROFILE)
echo ""
read -p "Informe o nome do AWS Profile [default]: " AWS_PROF
AWS_PROF=${AWS_PROF:-default}
export AWS_PROFILE="$AWS_PROF"
log_info "Perfil selecionado: AWS_PROFILE='$AWS_PROFILE'"

# 2. Verifica se já existe uma sessão de autenticação ativa e válida
log_info "Verificando se já existe uma sessão ativa para o perfil '$AWS_PROFILE'..."
set +e
IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ] && [ -n "$IDENTITY" ]; then
    ACCOUNT_ID=$(echo "$IDENTITY" | grep -o '"Account": "[^"]*' | cut -d'"' -f4)
    ARN=$(echo "$IDENTITY" | grep -o '"Arn": "[^"]*' | cut -d'"' -f4)
    USER_ID=$(echo "$IDENTITY" | grep -o '"UserId": "[^"]*' | cut -d'"' -f4)
    REGION=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "us-east-1")

    echo ""
    log_success "Sessão AWS já ativa e validada com sucesso para o perfil '$AWS_PROFILE'!"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "  ${YELLOW}Conta AWS (Account ID):${NC} $ACCOUNT_ID"
    echo -e "  ${YELLOW}ARN da Identidade:${NC}     $ARN"
    echo -e "  ${YELLOW}User ID / Role:${NC}        $USER_ID"
    echo -e "  ${YELLOW}Região Ativa:${NC}          $REGION"
    echo -e "  ${YELLOW}AWS Profile:${NC}           $AWS_PROFILE"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    exit 0
fi

log_warning "Nenhuma sessão ativa e válida detectada para o perfil '$AWS_PROFILE'."

echo -e "\n${CYAN}=====================================================${NC}"
echo -e "${CYAN}               Autenticação AWS                      ${NC}"
echo -e "${CYAN}=====================================================${NC}\n"

# 3. Fluxo de Autenticação (SSO ou chave estática) se nenhuma sessão ativa for encontrada
echo "Escolha o método de autenticação:"
echo "1) AWS SSO / AWS IAM Identity Center (Recomendado)"
echo "2) AWS Configure (Access Key ID / Secret Access Key)"
echo "3) Já estou autenticado / Pular esta etapa"

read -p "Opção [1-3] (padrão: 1): " AUTH_CHOICE
AUTH_CHOICE=${AUTH_CHOICE:-1}

case $AUTH_CHOICE in
    1)
        # Verifica se já há alguma configuração de SSO para o perfil para evitar reconfiguração total desnecessária
        set +e
        SSO_START_URL=$(aws configure get sso_start_url --profile "$AWS_PROFILE" 2>/dev/null)
        set -e

        if [ -n "$SSO_START_URL" ]; then
            log_info "Configurações de SSO detectadas para o perfil '$AWS_PROFILE'. Tentando login direto..."
            set +e
            aws sso login --profile "$AWS_PROFILE"
            LOGIN_STATUS=$?
            set -e
            if [ $LOGIN_STATUS -ne 0 ]; then
                log_warning "Não foi possível realizar login direto com SSO. Iniciando configuração completa do SSO..."
                aws configure sso
            fi
        else
            log_info "Iniciando wizard de configuração SSO da AWS..."
            aws configure sso
        fi
        ;;
    2)
        log_info "Iniciando configuração padrão do AWS CLI..."
        aws configure --profile "$AWS_PROFILE"
        ;;
    3)
        log_success "Etapa de autenticação pulada."
        ;;
    *)
        log_warning "Opção inválida. Prosseguindo com 'aws configure' padrão..."
        aws configure --profile "$AWS_PROFILE"
        ;;
esac

# 4. Teste final de validação se não pulou
if [ "$AUTH_CHOICE" != "3" ]; then
    log_info "Validando credenciais ativas na AWS..."
    set +e
    IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null)
    EXIT_CODE=$?
    set -e

    if [ $EXIT_CODE -eq 0 ] && [ -n "$IDENTITY" ]; then
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
        log_warning "Certifique-se de que o fluxo foi concluído ou que as credenciais são válidas."
        exit 1
    fi
fi

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}   Configuração concluída com sucesso!${NC}"
echo -e "${GREEN}=====================================================${NC}"
