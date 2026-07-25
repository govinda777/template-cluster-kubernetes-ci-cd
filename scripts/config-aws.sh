#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}   Configuração e Autenticação Automatizada - AWS CLI${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

# 1. Verifica se o AWS CLI já está instalado
if command -v aws &> /dev/null; then
    echo -e "${GREEN}[OK] AWS CLI já está instalado:${NC} $(aws --version)"
else
    echo -e "${YELLOW}[INFO] AWS CLI não foi encontrado. Iniciando instalação automática...${NC}"

    OS="$(uname -s)"
    case "${OS}" in
        Darwin*)
            echo -e "${BLUE}[INFO] Sistema operacional detectado: macOS${NC}"
            if command -v brew &> /dev/null; then
                echo -e "${BLUE}[INFO] Instalando AWS CLI via Homebrew...${NC}"
                brew install awscli
            else
                echo -e "${BLUE}[INFO] Homebrew não encontrado. Baixando instalador oficial .pkg da AWS...${NC}"
                curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "/tmp/AWSCLIV2.pkg"
                sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
                rm -f /tmp/AWSCLIV2.pkg
            fi
            ;;
        Linux*)
            echo -e "${BLUE}[INFO] Sistema operacional detectado: Linux${NC}"
            if ! command -v unzip &> /dev/null; then
                echo -e "${YELLOW}[INFO] Instalando dependência (unzip)...${NC}"
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

            echo -e "${BLUE}[INFO] Baixando e instalando AWS CLI v2 para ${ARCH}...${NC}"
            curl "https://awscli.amazonaws.com/${CLI_ZIP}" -o "/tmp/awscliv2.zip"
            unzip -q /tmp/awscliv2.zip -d /tmp/
            sudo /tmp/aws/install --update
            rm -rf /tmp/aws /tmp/awscliv2.zip
            ;;
        *)
            echo -e "${RED}[ERROR] Sistema operacional ${OS} não suportado para instalação automática.${NC}"
            echo "Por favor, instale o AWS CLI manualmente: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
            exit 1
            ;;
    esac

    # Garantir que o binário esteja no PATH da sessão atual se necessário
    export PATH="/usr/local/bin:$PATH"

    if command -v aws &> /dev/null; then
        echo -e "${GREEN}[OK] AWS CLI instalado com sucesso!${NC} ($(aws --version))"
    else
        echo -e "${RED}[ERROR] Falha ao verificar a instalação do AWS CLI.${NC}"
        exit 1
    fi
fi

echo -e "\n${BLUE}=====================================================${NC}"
echo -e "${BLUE}               Autenticação AWS${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

# 2. Fluxo de Autenticação (SSO ou chave estática)
echo "Escolha o método de autenticação:"
echo "1) AWS SSO / AWS IAM Identity Center (Recomendado)"
echo "2) AWS Configure (Access Key ID / Secret Access Key)"
echo "3) Já estou autenticado / Pular esta etapa"

read -p "Opção [1-3] (padrão: 1): " AUTH_CHOICE
AUTH_CHOICE=${AUTH_CHOICE:-1}

case $AUTH_CHOICE in
    1)
        echo -e "\n${BLUE}[INFO] Iniciando wizard de configuração SSO da AWS...${NC}"
        aws configure sso
        ;;
    2)
        echo -e "\n${BLUE}[INFO] Iniciando configuração padrão do AWS CLI...${NC}"
        aws configure
        ;;
    3)
        echo -e "\n${GREEN}[INFO] Etapa de autenticação pulada.${NC}"
        ;;
    *)
        echo -e "\n${YELLOW}[WARN] Opção inválida. Prosseguindo com 'aws configure' padrão...${NC}"
        aws configure
        ;;
esac

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}   Configuração concluída com sucesso!${NC}"
echo -e "${GREEN}=====================================================${NC}"
