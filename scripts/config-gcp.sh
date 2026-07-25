#!/usr/bin/env bash

set -e

# Unset conflicting static credential variables if any to ensure clean gcloud/ADC session
unset GOOGLE_APPLICATION_CREDENTIALS

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}   Configuração e Autenticação Automatizada - GCP (gcloud)${NC}"
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

# Helper to install Google Cloud SDK (gcloud CLI)
install_gcloud_sdk() {
    if command -v gcloud &> /dev/null; then
        echo -e "${GREEN}[OK] Google Cloud SDK (gcloud) já está instalado:${NC} $(gcloud --version | head -n 1)"
        return 0
    fi
    echo -e "${YELLOW}[INFO] gcloud CLI não foi encontrado. Iniciando instalação...${NC}"
    OS="$(uname -s)"
    case "${OS}" in
        Darwin*)
            echo -e "${BLUE}[INFO] Sistema operacional detectado: macOS${NC}"
            if command -v brew &> /dev/null; then
                echo -e "${BLUE}[INFO] Instalando google-cloud-sdk via Homebrew...${NC}"
                brew install --cask google-cloud-sdk
            else
                echo -e "${YELLOW}[WARN] Homebrew não encontrado. Baixando instalador interativo oficial do Google Cloud SDK...${NC}"
                curl -sSL https://sdk.cloud.google.com | bash
                exec -l $SHELL
            fi
            ;;
        Linux*)
            echo -e "${BLUE}[INFO] Sistema operacional detectado: Linux${NC}"
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
                curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
                echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
                sudo apt-get update && sudo apt-get install -y google-cloud-cli
            elif command -v dnf &> /dev/null || command -v yum &> /dev/null; then
                sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
                if command -v dnf &> /dev/null; then
                    sudo dnf install -y google-cloud-cli
                else
                    sudo yum install -y google-cloud-cli
                fi
            else
                echo -e "${BLUE}[INFO] Baixando instalador oficial via script...${NC}"
                curl -sSL https://sdk.cloud.google.com | bash
                exec -l $SHELL
            fi
            ;;
        *)
            echo -e "${RED}[ERROR] Sistema operacional ${OS} não suportado para instalação automática de gcloud.${NC}"
            echo "Por favor, instale o Google Cloud SDK manualmente: https://cloud.google.com/sdk/docs/install"
            exit 1
            ;;
    esac

    if command -v gcloud &> /dev/null; then
        echo -e "${GREEN}[OK] Google Cloud SDK instalado com sucesso!${NC} ($(gcloud --version | head -n 1))"
    else
        echo -e "${RED}[ERROR] Falha ao verificar a instalação do Google Cloud SDK.${NC}"
        exit 1
    fi
}

# Executa as verificações e instalações de dependências
echo -e "${BLUE}[INFO] Verificando e instalando dependências necessárias...${NC}"
install_git
install_gh
install_tofu
install_gcloud_sdk

echo -e "\n${BLUE}=====================================================${NC}"
echo -e "${BLUE}               Autenticação GCP & ADC${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

ENV_FILE=".gcp_profile_env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Validação de Sessão GCP / Usuário Ativo
validate_gcp_session() {
    local active_acct
    active_acct=$(gcloud config get-value account 2>/dev/null || echo "")
    if [ -n "$active_acct" ]; then
        return 0
    else
        return 1
    fi
}

SESSION_VALID=false
if validate_gcp_session; then
    SESSION_VALID=true
    ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
    echo -e "${GREEN}[OK] Sessão ativa e válida detectada para a conta: ${YELLOW}$ACTIVE_ACCOUNT${NC}"
else
    echo -e "${YELLOW}[WARN] Nenhuma sessão ativa válida detectada para o gcloud.${NC}"
fi

if [ "$SESSION_VALID" = "true" ]; then
    echo "Escolha uma opção:"
    echo "1) Continuar com a sessão atual (Recomendado)"
    echo "2) Realizar novo login interativo de usuário (gcloud auth login)"
    echo "3) Realizar login de Application Default Credentials (ADC)"
    echo "4) Autenticar usuário e ADC sequencialmente (Completo)"
    read -p "Opção [1-4] (padrão: 1): " AUTH_CHOICE
    AUTH_CHOICE=${AUTH_CHOICE:-1}
else
    echo "Escolha uma opção para autenticação no Google Cloud (GCP):"
    echo "1) Autenticar usuário e ADC sequencialmente (Completo / Recomendado)"
    echo "2) Apenas login interativo de usuário (gcloud auth login)"
    echo "3) Apenas login de Application Default Credentials (gcloud auth application-default login)"
    echo "4) Pular esta etapa"
    read -p "Opção [1-4] (padrão: 1): " AUTH_CHOICE
    AUTH_CHOICE=${AUTH_CHOICE:-1}
fi

CHOSEN_ACTION=""
if [ "$SESSION_VALID" = "true" ]; then
    case $AUTH_CHOICE in
        1) CHOSEN_ACTION="KEEP" ;;
        2) CHOSEN_ACTION="LOGIN" ;;
        3) CHOSEN_ACTION="ADC" ;;
        4) CHOSEN_ACTION="FULL" ;;
        *) echo -e "${YELLOW}[WARN] Opção inválida. Mantendo sessão atual.${NC}"; CHOSEN_ACTION="KEEP" ;;
    esac
else
    case $AUTH_CHOICE in
        1) CHOSEN_ACTION="FULL" ;;
        2) CHOSEN_ACTION="LOGIN" ;;
        3) CHOSEN_ACTION="ADC" ;;
        4) CHOSEN_ACTION="SKIP" ;;
        *) echo -e "${YELLOW}[WARN] Opção inválida. Executando autenticação completa...${NC}"; CHOSEN_ACTION="FULL" ;;
    esac
fi

if [ "$CHOSEN_ACTION" = "KEEP" ]; then
    echo -e "\n${GREEN}[INFO] Mantendo sessão ativa atual.${NC}"
elif [ "$CHOSEN_ACTION" = "SKIP" ]; then
    echo -e "\n${GREEN}[INFO] Etapa de autenticação pulada.${NC}"
elif [ "$CHOSEN_ACTION" = "LOGIN" ] || [ "$CHOSEN_ACTION" = "FULL" ]; then
    echo -e "\n${BLUE}[INFO] Iniciando autenticação do usuário no Google Cloud CLI (gcloud auth login)...${NC}"
    gcloud auth login
fi

if [ "$CHOSEN_ACTION" = "ADC" ] || [ "$CHOSEN_ACTION" = "FULL" ]; then
    echo -e "\n${BLUE}[INFO] Iniciando autenticação Application Default Credentials (ADC)...${NC}"
    if ! gcloud auth application-default login; then
        echo -e "${YELLOW}[WARN] Falha na autenticação via browser. Tentando com fluxo manual...${NC}"
        gcloud auth application-default login --no-launch-browser
    fi
fi

# Variável para rastrear erros detalhados do GCP
LAST_GCP_ERROR=""

# Helper para validação de permissões e pré-requisitos antes de criar projeto
validate_gcp_project_creation() {
    local project_id="$1"
    local project_name="$2"
    local err_file
    err_file=$(mktemp)

    echo -e "${BLUE}[INFO] Validando pré-requisitos para criação do projeto...${NC}"

    # 1. Validar formato do Project ID
    if [[ ! "$project_id" =~ ^[a-z][a-z0-9-]{4,29}[a-z0-9]$ ]]; then
        LAST_GCP_ERROR="Project ID inválido. Deve ter 6-30 caracteres, começar com letra minúscula, conter apenas letras minúsculas, números e hífens, e terminar com letra ou número."
        rm -f "$err_file"
        return 1
    fi

    # 2. Verificar se o Project ID já existe
    echo -e "${BLUE}[INFO] Verificando se o Project ID '$project_id' já existe...${NC}"
    if gcloud projects describe "$project_id" >/dev/null 2>"$err_file"; then
        LAST_GCP_ERROR="O Project ID '$project_id' já existe. Escolha outro ID."
        rm -f "$err_file"
        return 1
    fi
    rm -f "$err_file"

    # 3. Verificar permissão para criar projetos
    echo -e "${BLUE}[INFO] Verificando permissões para criar projetos...${NC}"
    ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "")
    if [ -z "$ACTIVE_ACCOUNT" ]; then
        LAST_GCP_ERROR="Nenhuma conta GCP autenticada. Execute 'gcloud auth login' primeiro."
        return 1
    fi

    # Tenta listar projetos para verificar permissão básica
    if ! gcloud projects list --limit 1 >/dev/null 2>"$err_file"; then
        local err_msg
        err_msg=$(cat "$err_file")
        rm -f "$err_file"
        LAST_GCP_ERROR="Sem permissão para listar projetos: $err_msg"
        return 1
    fi
    rm -f "$err_file"

    # 4. Verificar limites de projetos (se houver organização)
    echo -e "${BLUE}[INFO] Verificando limites de projetos na conta...${NC}"
    PROJECT_COUNT=$(gcloud projects list --format="value(projectId)" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}[OK] Conta atualmente tem $PROJECT_COUNT projeto(s).${NC}"

    # 5. Verificar se billing account está disponível (necessário para ativar APIs depois)
    echo -e "${BLUE}[INFO] Verificando contas de billing disponíveis...${NC}"
    BILLING_ACCOUNTS=$(gcloud billing accounts list --format="value(name)" 2>/dev/null || echo "")
    if [ -z "$BILLING_ACCOUNTS" ]; then
        echo -e "${YELLOW}[WARN] Nenhuma conta de billing detectada. Você precisará configurar billing após criar o projeto para habilitar APIs.${NC}"
    else
        BILLING_COUNT=$(echo "$BILLING_ACCOUNTS" | wc -l | tr -d ' ')
        echo -e "${GREEN}[OK] $BILLING_COUNT conta(s) de billing disponível(is).${NC}"
    fi

    echo -e "${GREEN}[OK] Todas as validações de pré-requisitos passaram.${NC}"
    return 0
}

# Configuração e Seleção do Project ID e Região
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -n "$CURRENT_PROJECT" ]; then
    echo -e "\nProjeto GCP atualmente ativo no gcloud: ${YELLOW}$CURRENT_PROJECT${NC}"
fi

read -p "Informe o GCP Project ID que deseja utilizar (deixe em branco para manter '$CURRENT_PROJECT', ou digite 'novo' para criar um projeto): " CHOSEN_PROJECT
CHOSEN_PROJECT=${CHOSEN_PROJECT:-$CURRENT_PROJECT}

if [ "$CHOSEN_PROJECT" = "novo" ] || [ -z "$CHOSEN_PROJECT" ]; then
    if [ "$CHOSEN_PROJECT" = "novo" ]; then
        echo -e "\n${BLUE}[INFO] Criando um novo projeto GCP...${NC}"
        read -p "Digite o nome do projeto (ex: meu-projeto-k8s): " PROJECT_NAME
        
        # Validação do nome do projeto
        if [ -z "$PROJECT_NAME" ]; then
            echo -e "${RED}[ERROR] O nome do projeto não pode ser vazio.${NC}"
            exit 1
        fi
        
        read -p "Digite o Project ID desejado (deixe em branco para gerar automaticamente): " CUSTOM_PROJECT_ID
        
        if [ -z "$CUSTOM_PROJECT_ID" ]; then
            # Gerar Project ID baseado no nome com sufixo aleatório
            RANDOM_SUFFIX=$(openssl rand -hex 4)
            # Converter nome para formato válido (lowercase, substituir espaços por hífens)
            SANITIZED_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -dc 'a-z0-9-')
            CUSTOM_PROJECT_ID="${SANITIZED_NAME}-${RANDOM_SUFFIX}"
        fi
        
        # Validar antes de criar
        if ! validate_gcp_project_creation "$CUSTOM_PROJECT_ID" "$PROJECT_NAME"; then
            echo -e "${RED}[ERROR] Validação falhou:${NC}"
            echo -e "${RED}  $LAST_GCP_ERROR${NC}"
            echo -e "\n${YELLOW}[DICA] Corrija o problema ou use um Project ID diferente.${NC}"
            exit 1
        fi
        
        echo -e "${BLUE}[INFO] Criando projeto '${PROJECT_NAME}' com ID '${CUSTOM_PROJECT_ID}'...${NC}"
        if gcloud projects create "$CUSTOM_PROJECT_ID" --name="$PROJECT_NAME"; then
            CHOSEN_PROJECT="$CUSTOM_PROJECT_ID"
            echo -e "${GREEN}[OK] Projeto criado com sucesso!${NC}"
            
            # Perguntar sobre configuração de billing
            echo -e "\n${YELLOW}[INFO] Para usar serviços GCP (GKE, etc.), você precisa configurar billing.${NC}"
            read -p "Deseja configurar billing agora? [y/N] (padrão: N): " CONFIGURE_BILLING
            CONFIGURE_BILLING=${CONFIGURE_BILLING:-N}
            
            if [[ "$CONFIGURE_BILLING" =~ ^[Yy]$ ]]; then
                BILLING_ACCOUNTS=$(gcloud billing accounts list --format="table(name,displayName)" 2>/dev/null || echo "")
                if [ -n "$BILLING_ACCOUNTS" ]; then
                    echo -e "\nContas de billing disponíveis:"
                    echo "$BILLING_ACCOUNTS"
                    read -p "Digite o ID da conta de billing (ex: 01ABC-XYZ123): " BILLING_ID
                    if [ -n "$BILLING_ID" ]; then
                        echo -e "${BLUE}[INFO] Vinculando conta de billing ao projeto...${NC}"
                        gcloud billing projects link "$CUSTOM_PROJECT_ID" --billing-account="$BILLING_ID"
                        echo -e "${GREEN}[OK] Billing configurado com sucesso!${NC}"
                    fi
                else
                    echo -e "${YELLOW}[WARN] Nenhuma conta de billing disponível. Configure manualmente no console: https://console.cloud.google.com/billing${NC}"
                fi
            fi
        else
            echo -e "${RED}[ERROR] Falha ao criar o projeto.${NC}"
            if [ -n "$LAST_GCP_ERROR" ]; then
                echo -e "${RED}  Detalhes: $LAST_GCP_ERROR${NC}"
            fi
            exit 1
        fi
    else
        echo -e "${RED}[ERROR] O Project ID do GCP não pode ser vazio.${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}[INFO] Definindo o projeto ativo para '$CHOSEN_PROJECT'...${NC}"
gcloud config set project "$CHOSEN_PROJECT"

# Pergunta sobre região e zona GCP
read -p "Informe a Região GCP desejada [us-central1]: " CHOSEN_REGION
CHOSEN_REGION=${CHOSEN_REGION:-us-central1}

read -p "Informe a Zona GCP desejada [${CHOSEN_REGION}-a]: " CHOSEN_ZONE
CHOSEN_ZONE=${CHOSEN_ZONE:-${CHOSEN_REGION}-a}

# Persistência das Variáveis Locais
GCP_PROJECT_ID="$CHOSEN_PROJECT"
GCP_REGION="$CHOSEN_REGION"
GCP_ZONE="$CHOSEN_ZONE"

echo -e "\n${BLUE}[INFO] Salvando as configurações em $ENV_FILE...${NC}"
cat << EOF > "$ENV_FILE"
GCP_PROJECT_ID=$GCP_PROJECT_ID
GCP_REGION=$GCP_REGION
GCP_ZONE=$GCP_ZONE
EOF
echo -e "${GREEN}[OK] Projeto, Região e Zona salvos com sucesso em $ENV_FILE!${NC}"

# Exibição do Resumo de Autenticação GCP
ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "Não identificada")

echo ""
echo -e "${CYAN}-----------------------------------------------------${NC}"
echo -e "  ${YELLOW}Autenticação Google Cloud concluída!${NC}"
echo -e "  ${YELLOW}Conta GCP Ativa:${NC}   $ACTIVE_ACCOUNT"
echo -e "  ${YELLOW}Projeto GCP Ativo:${NC} $GCP_PROJECT_ID"
echo -e "  ${YELLOW}Região GCP Ativa:${NC}  $GCP_REGION"
echo -e "  ${YELLOW}Zona GCP Ativa:${NC}    $GCP_ZONE"
echo -e "${CYAN}-----------------------------------------------------${NC}"

echo -e "\n${BLUE}=====================================================${NC}"
echo -e "${BLUE}    Bootstrap OIDC (Workload Identity) e GitHub${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

read -p "Deseja realizar o bootstrap do OIDC (WIF) e configurar os Secrets no GitHub automaticamente? [Y/n] (padrão: Y): " RUN_BOOTSTRAP
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

    # Garantir que as Application Default Credentials (ADC) do GCP estão válidas para o OpenTofu/Terraform
    echo -e "\n${BLUE}[INFO] Verificando validade das Application Default Credentials (ADC) do GCP...${NC}"
    if ! gcloud auth application-default print-access-token &>/dev/null; then
        echo -e "${YELLOW}[WARN] Application Default Credentials (ADC) não encontradas ou expiradas para o GCP.${NC}"
        echo -e "${BLUE}[INFO] Solicitando autenticação ADC (gcloud auth application-default login) para evitar falhas no OpenTofu...${NC}"
        if ! gcloud auth application-default login; then
            echo -e "${YELLOW}[WARN] Falha na autenticação via browser. Tentando com fluxo manual...${NC}"
            gcloud auth application-default login --no-launch-browser
        fi
    else
        echo -e "${GREEN}[OK] Application Default Credentials (ADC) estão ativas e válidas!${NC}"
    fi

    echo -e "\n${BLUE}[INFO] Inicializando o OpenTofu/Terraform para o Bootstrap do OIDC...${NC}"
    cd terraform/bootstrap

    $TOFU_BIN init -upgrade

    echo -e "\n${BLUE}[INFO] Aplicando recursos globais de Bootstrap (AWS OIDC & GCP WIF) via OpenTofu/Terraform...${NC}"
    # Carrega credenciais AWS locais se existirem para evitar falhas de validação nos recursos AWS do bootstrap
    if [ -f "../../.aws_profile_env" ]; then
        source "../../.aws_profile_env"
        export AWS_PROFILE
        export AWS_REGION
    fi

    $TOFU_BIN apply -auto-approve \
        -var="github_org_repo=$GITHUB_REPO" \
        -var="gcp_project_id=$GCP_PROJECT_ID" \
        -var="gcp_region=$GCP_REGION"

    # Capturar outputs
    echo -e "\n${BLUE}[INFO] Capturando saídas do Terraform...${NC}"
    WIF_PROVIDER=$($TOFU_BIN output -raw gcp_workload_identity_provider 2>/dev/null || true)
    DEV_SA=$($TOFU_BIN output -raw gcp_service_account_dev 2>/dev/null || true)
    PROD_SA=$($TOFU_BIN output -raw gcp_service_account_prod 2>/dev/null || true)
    TEST_SA=$($TOFU_BIN output -raw gcp_service_account_test 2>/dev/null || true)

    cd ../..

    if [ -z "$WIF_PROVIDER" ] || [ -z "$DEV_SA" ] || [ -z "$PROD_SA" ] || [ -z "$TEST_SA" ]; then
        echo -e "${RED}[ERROR] Falha ao capturar as saídas (outputs) do OIDC GCP.${NC}"
        exit 1
    fi

    # Salvar segredos no GitHub
    echo -e "\n${BLUE}[INFO] Salvando as configurações e secrets no repositório GitHub...${NC}"
    gh secret set GCP_PROJECT_ID -b "${GCP_PROJECT_ID}" --repo "${GITHUB_REPO}"
    gh secret set GCP_REGION -b "${GCP_REGION}" --repo "${GITHUB_REPO}"
    gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER -b "${WIF_PROVIDER}" --repo "${GITHUB_REPO}"
    gh secret set GCP_SERVICE_ACCOUNT_DEV -b "${DEV_SA}" --repo "${GITHUB_REPO}"
    gh secret set GCP_SERVICE_ACCOUNT_PROD -b "${PROD_SA}" --repo "${GITHUB_REPO}"
    gh secret set GCP_SERVICE_ACCOUNT_TEST -b "${TEST_SA}" --repo "${GITHUB_REPO}"

    echo -e "${GREEN}[OK] Todos os Secrets GCP foram salvos com sucesso no GitHub!${NC}"
else
    echo -e "\n${YELLOW}[INFO] Bootstrap do OIDC GCP pulado.${NC}"
fi

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}   Configuração GCP concluída com sucesso!${NC}"
echo -e "${GREEN}=====================================================${NC}"
