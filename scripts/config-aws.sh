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

# Helper to install Git
install_git() {
    if command -v git &> /dev/null; then
        echo -e "${GREEN}[OK] Git já está instalado:${NC} $(git --version)"
        return 0
    fi
    echo -e "${YELLOW}[INFO] Git não foi encontrado. Iniciando instalação...${NC}"
    OS="$(uname -s)"
    case "${OS}" in
        Darwin*)
            if command -v brew &> /dev/null; then
                brew install git
            else
                echo -e "${RED}[ERROR] Homebrew não encontrado. Instale o Git manualmente.${NC}"
                exit 1
            fi
            ;;
        Linux*)
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y git
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y git
            elif command -v yum &> /dev/null; then
                sudo yum install -y git
            else
                echo -e "${RED}[ERROR] Gerenciador de pacotes não suportado. Instale o Git manualmente.${NC}"
                exit 1
            fi
            ;;
    esac
}

# Helper to install GitHub CLI (gh)
install_gh() {
    if command -v gh &> /dev/null; then
        echo -e "${GREEN}[OK] GitHub CLI (gh) já está instalado:${NC} $(gh --version | head -n 1)"
        return 0
    fi
    echo -e "${YELLOW}[INFO] GitHub CLI (gh) não foi encontrado. Iniciando instalação...${NC}"
    OS="$(uname -s)"
    case "${OS}" in
        Darwin*)
            if command -v brew &> /dev/null; then
                brew install gh
            else
                echo -e "${RED}[ERROR] Homebrew não encontrado. Instale o gh manualmente.${NC}"
                exit 1
            fi
            ;;
        Linux*)
            if command -v apt-get &> /dev/null; then
                sudo mkdir -p -m 755 /etc/apt/keyrings
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
                sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                sudo apt-get update && sudo apt-get install -y gh
            elif command -v dnf &> /dev/null; then
                sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                sudo dnf install -y gh
            elif command -v yum &> /dev/null; then
                sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                sudo yum install -y gh
            else
                echo -e "${BLUE}[INFO] Baixando binário pré-compilado do gh...${NC}"
                GH_VERSION="2.45.0"
                ARCH="$(uname -m)"
                if [ "$ARCH" = "x86_64" ]; then GH_ARCH="amd64"; else GH_ARCH="arm64"; fi
                curl -sSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" -o "/tmp/gh.tar.gz"
                tar -xzf /tmp/gh.tar.gz -C /tmp/
                sudo mv /tmp/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh /usr/local/bin/gh
                rm -rf /tmp/gh.tar.gz /tmp/gh_${GH_VERSION}_linux_${GH_ARCH}
            fi
            ;;
    esac
}

# Helper to install OpenTofu
install_tofu() {
    if command -v tofu &> /dev/null; then
        echo -e "${GREEN}[OK] OpenTofu (tofu) já está instalado:${NC} $(tofu --version | head -n 1)"
        return 0
    elif command -v terraform &> /dev/null; then
        echo -e "${GREEN}[OK] Terraform já está instalado:${NC} $(terraform --version | head -n 1)"
        return 0
    fi
    echo -e "${YELLOW}[INFO] OpenTofu/Terraform não encontrado. Iniciando instalação do OpenTofu...${NC}"
    OS="$(uname -s)"
    case "${OS}" in
        Darwin*)
            if command -v brew &> /dev/null; then
                brew install opentofu
            else
                curl -fsSL https://get.opentofu.org/install.sh | sh -s -- --install-method standalone
            fi
            ;;
        Linux*)
            curl -fsSL https://get.opentofu.org/install.sh | sh -s -- --install-method standalone
            ;;
    esac
}

# Helper to install AWS CLI
install_aws_cli() {
    if command -v aws &> /dev/null; then
        echo -e "${GREEN}[OK] AWS CLI já está instalado:${NC} $(aws --version)"
        return 0
    fi
    echo -e "${YELLOW}[INFO] AWS CLI não foi encontrado. Iniciando instalação...${NC}"

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
}

# 1. Executa as verificações e instalações de dependências
echo -e "${BLUE}[INFO] Verificando e instalando dependências necessárias...${NC}"
install_git
install_gh
install_tofu
install_aws_cli

echo -e "\n${BLUE}=====================================================${NC}"
echo -e "${BLUE}               Autenticação AWS${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

# 2. Fluxo de Autenticação (SSO ou chave estática)
ALREADY_AUTHENTICATED=false
if aws sts get-caller-identity &>/dev/null; then
    echo -e "${GREEN}[OK] Você já possui uma sessão ativa na AWS!${NC}"
    aws sts get-caller-identity
    ALREADY_AUTHENTICATED=true
fi

if [ "$ALREADY_AUTHENTICATED" = "true" ]; then
    echo "Escolha uma opção:"
    echo "1) Continuar com a sessão atual (Recomendado)"
    echo "2) Realizar nova autenticação AWS SSO"
    echo "3) Realizar nova configuração de chaves estáticas (AWS Configure)"
    read -p "Opção [1-3] (padrão: 1): " AUTH_CHOICE
    AUTH_CHOICE=${AUTH_CHOICE:-1}
else
    echo "Escolha o método de autenticação:"
    echo "1) AWS SSO / AWS IAM Identity Center (Recomendado)"
    echo "2) AWS Configure (Access Key ID / Secret Access Key)"
    echo "3) Pular esta etapa"
    read -p "Opção [1-3] (padrão: 1): " AUTH_CHOICE
    AUTH_CHOICE=${AUTH_CHOICE:-1}
fi

if [ "$ALREADY_AUTHENTICATED" = "true" ] && [ "$AUTH_CHOICE" = "1" ]; then
    echo -e "\n${GREEN}[INFO] Mantendo sessão ativa atual.${NC}"
else
    # Mapear escolhas para não autenticado se for uma nova autenticação
    if [ "$ALREADY_AUTHENTICATED" = "true" ]; then
        if [ "$AUTH_CHOICE" = "2" ]; then REAL_CHOICE=1; else REAL_CHOICE=2; fi
    else
        REAL_CHOICE=$AUTH_CHOICE
    fi

    case $REAL_CHOICE in
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
            echo -e "\n${YELLOW}[WARN] Opção inválida. Prosseguindo...${NC}"
            ;;
    esac
fi

# Validar se a autenticação funcionou antes de prosseguir
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "\n${RED}[ERROR] Nenhuma sessão ativa válida detectada na AWS. Por favor, autentique-se primeiro.${NC}"
    exit 1
fi

echo -e "\n${BLUE}=====================================================${NC}"
echo -e "${BLUE}       Bootstrap OIDC e Configuração GitHub${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

read -p "Deseja realizar o bootstrap do OIDC e configurar os Secrets no GitHub automaticamente? [Y/n]: " RUN_BOOTSTRAP
RUN_BOOTSTRAP=${RUN_BOOTSTRAP:-Y}

if [[ "$RUN_BOOTSTRAP" =~ ^[Yy]$ ]]; then
    # Garantir autenticação com GitHub CLI (gh)
    echo -e "\n${BLUE}[INFO] Verificando status de autenticação no GitHub CLI...${NC}"
    if ! gh auth status &>/dev/null; then
        echo -e "${YELLOW}[WARN] GitHub CLI não está autenticado. Iniciando login interativo...${NC}"
        gh auth login
    else
        echo -e "${GREEN}[OK] GitHub CLI está autenticado!${NC}"
    fi

    # Detectar repositório
    echo -e "\n${BLUE}[INFO] Detectando repositório GitHub...${NC}"
    GITHUB_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
    if [ -z "$GITHUB_REPO" ]; then
        GITHUB_REPO=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:\/](.*)\.git/\1/' || true)
    fi
    if [ -z "$GITHUB_REPO" ]; then
        read -p "Não conseguimos detectar o repositório automaticamente. Digite o formato (owner/repo): " GITHUB_REPO
    fi
    echo -e "${GREEN}[OK] Repositório detectado:${NC} ${GITHUB_REPO}"

    # Executar OpenTofu/Terraform
    TOFU_BIN="tofu"
    if ! command -v tofu &> /dev/null; then
        TOFU_BIN="terraform"
    fi

    echo -e "\n${BLUE}[INFO] Inicializando o OpenTofu/Terraform para o Bootstrap do OIDC...${NC}"
    cd terraform/bootstrap
    $TOFU_BIN init

    AWS_REGION_DETEC=$(aws configure get region 2>/dev/null || echo "us-east-1")
    read -p "Qual região da AWS deseja utilizar para o OIDC? [$AWS_REGION_DETEC]: " AWS_REG
    AWS_REG=${AWS_REG:-$AWS_REGION_DETEC}

    echo -e "\n${BLUE}[INFO] Aplicando recursos na AWS via OpenTofu/Terraform...${NC}"
    $TOFU_BIN apply -auto-approve -var="aws_region=$AWS_REG" -var="github_org_repo=$GITHUB_REPO"

    # Capturar outputs
    echo -e "\n${BLUE}[INFO] Capturando saídas do Terraform...${NC}"
    DEV_ROLE_ARN=$($TOFU_BIN output -raw github_role_to_assume_dev 2>/dev/null || true)
    PROD_ROLE_ARN=$($TOFU_BIN output -raw github_role_to_assume_prod 2>/dev/null || true)
    TEST_ROLE_ARN=$($TOFU_BIN output -raw github_role_to_assume_test 2>/dev/null || true)
    BOOTSTRAP_REGION=$($TOFU_BIN output -raw aws_region 2>/dev/null || echo "$AWS_REG")

    cd ../..

    if [ -z "$DEV_ROLE_ARN" ] || [ -z "$PROD_ROLE_ARN" ] || [ -z "$TEST_ROLE_ARN" ]; then
        echo -e "${RED}[ERROR] Falha ao capturar as ARNs das Roles criadas.${NC}"
        exit 1
    fi

    # Salvar segredos no GitHub
    echo -e "\n${BLUE}[INFO] Salvando as configurações e secrets no repositório GitHub...${NC}"
    gh secret set AWS_REGION -b "${BOOTSTRAP_REGION}" --repo "${GITHUB_REPO}"
    gh secret set AWS_REGION_PROD -b "${BOOTSTRAP_REGION}" --repo "${GITHUB_REPO}"
    gh secret set AWS_ROLE_TO_ASSUME_DEV -b "${DEV_ROLE_ARN}" --repo "${GITHUB_REPO}"
    gh secret set AWS_ROLE_TO_ASSUME_PROD -b "${PROD_ROLE_ARN}" --repo "${GITHUB_REPO}"
    gh secret set AWS_ROLE_TO_ASSUME_TEST -b "${TEST_ROLE_ARN}" --repo "${GITHUB_REPO}"

    echo -e "${GREEN}[OK] Todos os Secrets foram salvos com sucesso no GitHub!${NC}"
else
    echo -e "\n${YELLOW}[INFO] Bootstrap do OIDC pulado.${NC}"
fi

echo -e "\n${BLUE}=====================================================${NC}"
echo -e "${BLUE}         Configuração do Git com AWS${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

# 4. Configuração do Git local com AWS
echo -e "${BLUE}[INFO] Configurando o auxiliar de credenciais do Git (Credential Helper) para AWS...${NC}"
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

echo -e "${GREEN}[OK] Git configurado com sucesso!${NC}"

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}   Configuração concluída com sucesso!${NC}"
echo -e "${GREEN}=====================================================${NC}"
