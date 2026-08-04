#!/usr/bin/env bash

set -e

# Unset conflicting static credential environment variables to avoid overriding the profile
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}   Configuração e Autenticação Automatizada - AWS SSO${NC}"
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
echo -e "${BLUE}               Autenticação AWS SSO${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

ENV_FILE=".aws_profile_env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

get_sso_profiles() {
    local config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    if [ ! -f "$config_file" ]; then
        return 0
    fi
    awk '
    /^\[profile / {
        sub(/^\[profile /, "", $0);
        sub(/\]$/, "", $0);
        current_profile = $0;
    }
    /^\[default\]/ {
        current_profile = "default";
    }
    /sso_/ {
        if (current_profile != "") {
            sso_profiles[current_profile] = 1;
        }
    }
    END {
        for (p in sso_profiles) {
            print p;
        }
    }
    ' "$config_file"
}

get_last_sso_profile() {
    local config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    if [ ! -f "$config_file" ]; then
        return 0
    fi
    awk '
    /^\[profile / {
        sub(/^\[profile /, "", $0);
        sub(/\]$/, "", $0);
        current_profile = $0;
    }
    /^\[default\]/ {
        current_profile = "default";
    }
    /sso_/ {
        if (current_profile != "") {
            last_sso = current_profile;
        }
    }
    END {
        if (last_sso != "") {
            print last_sso;
        }
    }
    ' "$config_file"
}

# Variável para rastrear erros detalhados do STS
LAST_STS_ERROR=""

# Helper para validação robusta do STS
validate_session() {
    local profile="$1"
    local region="$2"
    local err_file
    err_file=$(mktemp)

    # Se a região não foi passada, tenta descobrir
    if [ -z "$region" ]; then
        region=$(aws configure get region --profile "$profile" 2>/dev/null || echo "us-east-1")
    fi

    # Executa validação capturando stderr
    if aws sts get-caller-identity --profile "$profile" --region "$region" >/dev/null 2>"$err_file"; then
        rm -f "$err_file"
        return 0
    else
        local err_msg
        err_msg=$(cat "$err_file")
        rm -f "$err_file"
        LAST_STS_ERROR="$err_msg"
        return 1
    fi
}

SESSION_VALID=false
if [ -n "$AWS_PROFILE" ]; then
    echo -e "${BLUE}[INFO] Detectado perfil anterior no arquivo de ambiente: ${YELLOW}$AWS_PROFILE${NC}"
    if validate_session "$AWS_PROFILE" "$AWS_REGION"; then
        SESSION_VALID=true
        echo -e "${GREEN}[OK] Sessão activa e válida detectada para o perfil: ${YELLOW}$AWS_PROFILE${NC}"
    else
        echo -e "${YELLOW}[WARN] Sessão expirada ou inválida para o perfil: ${YELLOW}$AWS_PROFILE${NC}"
        if [ -n "$LAST_STS_ERROR" ]; then
            echo -e "${RED}  Detalhes do erro: $LAST_STS_ERROR${NC}"
        fi
    fi
fi

if [ "$SESSION_VALID" = "true" ]; then
    echo "Escolha uma opção:"
    echo "1) Continuar com a sessão atual (Recomendado)"
    echo "2) Realizar novo login SSO neste perfil (aws sso login)"
    echo "3) Configurar uma nova sessão/perfil SSO (aws configure sso)"
    echo "4) Selecionar outro perfil SSO existente"
    read -p "Opção [1-4] (padrão: 1): " AUTH_CHOICE
    AUTH_CHOICE=${AUTH_CHOICE:-1}
else
    echo "Escolha uma opção para autenticação via AWS SSO:"
    echo "1) Realizar login SSO com um perfil existente (aws sso login)"
    echo "2) Configurar um novo perfil SSO (aws configure sso)"
    echo "3) Pular esta etapa"
    read -p "Opção [1-3] (padrão: 1): " AUTH_CHOICE
    AUTH_CHOICE=${AUTH_CHOICE:-1}
fi

CHOSEN_ACTION=""
if [ "$SESSION_VALID" = "true" ]; then
    case $AUTH_CHOICE in
        1)
            CHOSEN_ACTION="KEEP"
            ;;
        2)
            CHOSEN_ACTION="LOGIN"
            ;;
        3)
            CHOSEN_ACTION="CONFIGURE"
            ;;
        4)
            CHOSEN_ACTION="SELECT"
            ;;
        *)
            echo -e "${YELLOW}[WARN] Opção inválida. Mantendo sessão atual.${NC}"
            CHOSEN_ACTION="KEEP"
            ;;
    esac
else
    case $AUTH_CHOICE in
        1)
            CHOSEN_ACTION="SELECT" # Vai para a seleção antes de logar
            ;;
        2)
            CHOSEN_ACTION="CONFIGURE"
            ;;
        3)
            CHOSEN_ACTION="SKIP"
            ;;
        *)
            echo -e "${YELLOW}[WARN] Opção inválida. Prosseguindo para configuração...${NC}"
            CHOSEN_ACTION="CONFIGURE"
            ;;
    esac
fi

if [ "$CHOSEN_ACTION" = "KEEP" ]; then
    echo -e "\n${GREEN}[INFO] Mantendo sessão ativa atual.${NC}"
elif [ "$CHOSEN_ACTION" = "SKIP" ]; then
    echo -e "\n${GREEN}[INFO] Etapa de autenticação pulada.${NC}"
elif [ "$CHOSEN_ACTION" = "CONFIGURE" ]; then
    echo -e "\n${BLUE}[INFO] Iniciando wizard de configuração SSO da AWS...${NC}"
    aws configure sso

    # Captura inteligente do perfil
    DETECTED_PROFILE=$(get_last_sso_profile)
    if [ -n "$DETECTED_PROFILE" ]; then
        echo -e "\n${GREEN}[INFO] Perfil SSO detectado automaticamente: ${YELLOW}$DETECTED_PROFILE${NC}"
        read -p "Deseja utilizar este perfil? [Y/n] (padrão: Y): " CONFIRM_PROFILE
        CONFIRM_PROFILE=${CONFIRM_PROFILE:-Y}
        if [[ "$CONFIRM_PROFILE" =~ ^[Yy]$ ]]; then
            AWS_PROFILE="$DETECTED_PROFILE"
        else
            AWS_PROFILE=""
        fi
    fi

    # Se falhou em detectar ou o usuário rejeitou, cai no Fallback (Opção A)
    if [ -z "$AWS_PROFILE" ]; then
        echo -e "\n${BLUE}[INFO] Selecione um perfil SSO da lista de perfis disponíveis:${NC}"
        PROFILES=($(get_sso_profiles))
        if [ ${#PROFILES[@]} -eq 0 ]; then
            echo -e "${YELLOW}[WARN] Nenhum perfil SSO configurado foi encontrado em ~/.aws/config.${NC}"
            read -p "Por favor, digite o nome do perfil que acabou de configurar: " AWS_PROFILE
        else
            echo -e "Perfis SSO configurados:"
            for i in "${!PROFILES[@]}"; do
                echo -e "  $((i+1))) ${PROFILES[$i]}"
            done
            read -p "Selecione o número do perfil ou digite o nome do perfil desejado: " PROFILE_CHOICE
            if [[ "$PROFILE_CHOICE" =~ ^[0-9]+$ ]] && [ "$PROFILE_CHOICE" -le "${#PROFILES[@]}" ] && [ "$PROFILE_CHOICE" -gt 0 ]; then
                AWS_PROFILE="${PROFILES[$((PROFILE_CHOICE-1))]}"
            else
                AWS_PROFILE="$PROFILE_CHOICE"
            fi
        fi
    fi
elif [ "$CHOSEN_ACTION" = "SELECT" ] || [ "$CHOSEN_ACTION" = "LOGIN" ]; then
    # Se escolheu login no perfil já carregado
    if [ "$CHOSEN_ACTION" = "LOGIN" ] && [ -n "$AWS_PROFILE" ]; then
        echo -e "\n${BLUE}[INFO] Realizando login no perfil atual: ${YELLOW}$AWS_PROFILE${NC}"
        aws sso login --profile "$AWS_PROFILE"
    else
        # Senão, seleciona um da lista e loga
        PROFILES=($(get_sso_profiles))
        if [ ${#PROFILES[@]} -eq 0 ]; then
            echo -e "${YELLOW}[WARN] Nenhum perfil SSO configurado foi encontrado em ~/.aws/config.${NC}"
            echo -e "${BLUE}[INFO] Por favor, rode a opção de configuração primeiro.${NC}"
            read -p "Se você já possui um perfil configurado e sabe o nome, digite-o aqui: " AWS_PROFILE
        else
            echo -e "\nPerfis SSO disponíveis:"
            for i in "${!PROFILES[@]}"; do
                echo -e "  $((i+1))) ${PROFILES[$i]}"
            done
            read -p "Selecione o número do perfil ou digite o nome do perfil desejado: " PROFILE_CHOICE
            if [[ "$PROFILE_CHOICE" =~ ^[0-9]+$ ]] && [ "$PROFILE_CHOICE" -le "${#PROFILES[@]}" ] && [ "$PROFILE_CHOICE" -gt 0 ]; then
                AWS_PROFILE="${PROFILES[$((PROFILE_CHOICE-1))]}"
            else
                AWS_PROFILE="$PROFILE_CHOICE"
            fi
        fi

        if [ -n "$AWS_PROFILE" ]; then
            echo -e "\n${BLUE}[INFO] Iniciando login SSO para o perfil: ${YELLOW}$AWS_PROFILE${NC}"
            aws sso login --profile "$AWS_PROFILE"
        fi
    fi
fi

# Validar se a autenticação funcionou antes de prosseguir (Validação e Auto-Login)
if [ -n "$AWS_PROFILE" ]; then
    AWS_REGION=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "us-east-1")

    echo -e "\n${BLUE}[INFO] Validando sessão ativa para o perfil '${YELLOW}$AWS_PROFILE${NC}'...${NC}"
    if ! validate_session "$AWS_PROFILE" "$AWS_REGION"; then
        echo -e "${YELLOW}[WARN] Sessão inválida ou expirada para o perfil '${YELLOW}$AWS_PROFILE${NC}'. Tentando login automático...${NC}"
        if aws sso login --profile "$AWS_PROFILE"; then
            echo -e "${GREEN}[OK] Login SSO realizado com sucesso.${NC}"
        else
            echo -e "${RED}[ERROR] Falha ao tentar realizar login SSO para o perfil '${YELLOW}$AWS_PROFILE${NC}'.${NC}"
            exit 1
        fi
    fi

    # Validação final e exibição das informações do STS
    STS_OUTPUT=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null || true)
    if [ -n "$STS_OUTPUT" ]; then
        ACCOUNT_ID=$(echo "$STS_OUTPUT" | awk -F'"' '/Account/ {print $4}')
        USER_ID=$(echo "$STS_OUTPUT" | awk -F'"' '/UserId/ {print $4}')
        ARN=$(echo "$STS_OUTPUT" | awk -F'"' '/Arn/ {print $4}')
        echo -e "${GREEN}[OK] Sessão AWS SSO validada com sucesso!${NC}"
        echo -e "${GREEN}  - Conta (Account ID): ${YELLOW}$ACCOUNT_ID${NC}"
        echo -e "${GREEN}  - Usuário (UserId): ${YELLOW}$USER_ID${NC}"
        echo -e "${GREEN}  - ARN: ${YELLOW}$ARN${NC}"
    else
        # Executa de novo para capturar o erro exato
        validate_session "$AWS_PROFILE" "$AWS_REGION"
        echo -e "\n${RED}[ERROR] Nenhuma sessão ativa válida detectada na AWS para o perfil '${YELLOW}$AWS_PROFILE${NC}'. Por favor, autentique-se primeiro.${NC}"
        if [ -n "$LAST_STS_ERROR" ]; then
            echo -e "${RED}Detalhes do erro retornado pela AWS CLI:${NC}\n${YELLOW}$LAST_STS_ERROR${NC}"
            echo -e "\n${BLUE}[DICA] Certifique-se de que não existem variáveis de ambiente de chaves estáticas conflitantes (ex: AWS_ACCESS_KEY_ID ou AWS_SECRET_ACCESS_KEY) ativas no seu terminal. O script já tentou limpá-las nesta execução, mas convém verificar o seu shell.${NC}"
        fi
        exit 1
    fi
else
    if [ "$CHOSEN_ACTION" != "SKIP" ]; then
        echo -e "\n${RED}[ERROR] Nenhum perfil de autenticação foi selecionado ou configurado.${NC}"
        exit 1
    fi
fi

# Persistência das Variáveis
if [ -n "$AWS_PROFILE" ]; then
    AWS_REGION=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "")
    if [ -z "$AWS_REGION" ]; then
        AWS_REGION="us-east-1"
    fi

    echo -e "\n${BLUE}[INFO] Salvando as configurações em $ENV_FILE...${NC}"
    cat << EOF > "$ENV_FILE"
AWS_PROFILE=$AWS_PROFILE
AWS_REGION=$AWS_REGION
EOF
    echo -e "${GREEN}[OK] Perfil e Região salvos com sucesso em $ENV_FILE!${NC}"
fi

echo -e "\n${BLUE}=====================================================${NC}"
echo -e "${BLUE}       Bootstrap OIDC e Configuração GitHub${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

read -p "Deseja realizar o bootstrap do OIDC e configurar os Secrets no GitHub automaticamente? [Y/n] (padrão: Y): " RUN_BOOTSTRAP
RUN_BOOTSTRAP=${RUN_BOOTSTRAP:-Y}

if [[ "$RUN_BOOTSTRAP" =~ ^[Yy]$ ]]; then
    if [ -z "$AWS_PROFILE" ]; then
        echo -e "${RED}[ERROR] O bootstrap do OIDC requer uma sessão ativa da AWS. Configure a autenticação primeiro.${NC}"
        exit 1
    fi

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

    # Exportar variáveis para herança no OpenTofu/Terraform
    export AWS_PROFILE="$AWS_PROFILE"
    export AWS_REGION="$AWS_REGION"

    $TOFU_BIN init -upgrade

    AWS_REGION_DETEC=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "us-east-1")
    read -p "Qual região da AWS deseja utilizar para o OIDC? [$AWS_REGION_DETEC]: " AWS_REG
    AWS_REG=${AWS_REG:-$AWS_REGION_DETEC}

    # Atualiza a região exportada se o usuário escolheu outra
    export AWS_REGION="$AWS_REG"

    # Carregar variáveis do GCP se existirem para herança no bootstrap
    GCP_PROJECT_VAR=""
    GCP_REGION_VAR=""
    if [ -f "../../.gcp_profile_env" ]; then
        source "../../.gcp_profile_env"
        if [ -n "$GCP_PROJECT_ID" ]; then
            GCP_PROJECT_VAR="-var=gcp_project_id=$GCP_PROJECT_ID"
        fi
        if [ -n "$GCP_REGION" ]; then
            GCP_REGION_VAR="-var=gcp_region=$GCP_REGION"
        fi
    fi

    echo -e "\n${BLUE}[INFO] Aplicando recursos na AWS via OpenTofu/Terraform...${NC}"
    $TOFU_BIN apply -auto-approve -var="aws_region=$AWS_REG" -var="github_org_repo=$GITHUB_REPO" ${GCP_PROJECT_VAR} ${GCP_REGION_VAR}

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
git config --local credential.helper '!aws codecommit credential-helper $@'
git config --local credential.UseHttpPath true

echo -e "${GREEN}[OK] Git configurado com sucesso!${NC}"

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}   Configuração concluída com sucesso!${NC}"
echo -e "${GREEN}=====================================================${NC}"