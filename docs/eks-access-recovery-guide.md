# Runbook Definitivo: Diagnóstico e Recuperação de Acesso ao Amazon EKS

Este runbook técnico foi desenvolvido pela Engenharia Principal de Plataforma e Cloud para servir como guia definitivo na resolução de problemas de acesso e autenticação ao cluster Kubernetes (Amazon EKS) usando `kubectl` ou via Console da AWS.

---

## CONTEXTO DO PROBLEMA

### Sintoma
Ao tentar acessar o cluster Kubernetes usando `kubectl` ou pelo Console da AWS, você recebe a seguinte mensagem de erro:
> *"A entidade principal do IAM atual não tem acesso a objetos do Kubernetes neste cluster. Isso pode ocorrer porque o usuário ou perfil atual não tem permissões RBAC do Kubernetes para descrever recursos de cluster ou não tem uma entrada no mapa de configuração de autenticação do cluster."*

### Causa Raiz
No Amazon EKS, o usuário ou role do IAM que **cria o cluster** recebe automaticamente e de forma implícita acesso total de administração (`system:masters`) no RBAC do Kubernetes. Esse mapeamento:
1. **É invisível:** Não aparece no ConfigMap `aws-auth` ou nas configurações iniciais do IAM.
2. **É exclusivo:** Nenhuma outra entidade do IAM (incluindo o usuário Root da conta AWS ou outros administradores com a política `AdministratorAccess`) terá acesso inicial ao cluster.
3. **Ponto Único de Falha:** Se o criador do cluster foi um usuário IAM físico deletado, ou se as credenciais foram perdidas (como uma Role temporária de pipeline de CI/CD), ocorre o bloqueio de acesso generalizado (*lockout*).

---

## PASSO 1: DIAGNÓSTICO DO AMBIENTE VIA AWS CLI

Execute os seguintes passos para diagnosticar qual identidade você está usando localmente, quem criou o cluster e qual é o modo de autenticação ativo.

### 1.1 Identificar a Identidade IAM Ativa Localmente
Para descobrir qual identidade IAM está configurada em seu terminal após a execução do `make config aws`:

```bash
# Exibir o usuário ou a role do IAM em uso na sessão do terminal
aws sts get-caller-identity --output json
```
*Anote o campo `"Arn"` retornado (ex: `arn:aws:iam::123456789012:user/nome-usuario` ou `arn:aws:sts::123456789012:assumed-role/AWSReservedSSO_Admin_xxx/usuario`).*

### 1.2 Investigar o Criador do Cluster EKS
Se o cluster foi criado por IA/IAC ou manualmente por um engenheiro, podemos rastrear a chamada na AWS para verificar se o criador do cluster ainda existe.

#### Método A: Busca de Eventos no CloudTrail (Event history)
O evento que registra a criação do cluster é o `CreateCluster`.

```bash
# Buscar nos últimos 90 dias qual entidade IAM disparou a criação do cluster
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventName,AttributeValue=CreateCluster \
    --query "Events[].{Time: EventTime, Principal: Username, EventData: CloudTrailEvent}" \
    --output json
```
*Procure por `"userIdentity"` dentro de `"EventData"` para localizar o ARN do criador.*

#### Método B: Consultar as Tags do Cluster EKS
Frequentemente, ferramentas de infraestrutura como código (Terraform/OpenTofu) rotulam o recurso.

```bash
# Listar tags do cluster (substitua <CLUSTER_NAME> e <REGION>)
aws eks describe-cluster \
    --name <CLUSTER_NAME> \
    --region <REGION> \
    --query "cluster.tags" \
    --output json
```

### 1.3 Listar e Validar Usuários/Roles no IAM
Verifique se a entidade criadora ou outras identidades ainda estão ativas no AWS IAM:

```bash
# Listar todos os usuários do IAM na conta
aws iam list-users --query "Users[].UserName" --output json

# Listar todas as roles do IAM na conta
aws iam list-roles --query "Roles[].RoleName" --output json

# Validar se um usuário IAM específico existe
aws iam get-user --user-name <NOME_DO_USUARIO_CRIADOR> 2>/dev/null || echo "Usuário NÃO existe mais ou está inacessível!"

# Validar se uma Role IAM específica existe
aws iam get-role --role-name <NOME_DA_ROLE_CRIADORA> 2>/dev/null || echo "Role NÃO existe mais ou está inacessível!"
```

### 1.4 Consultar o Modo de Autenticação (`authenticationMode`)
Os clusters modernos do EKS utilizam novos modos de gerenciamento de acesso que eliminam a necessidade do ConfigMap `aws-auth` em Kubernetes.

```bash
# Consultar o modo de autenticação configurado no cluster
aws eks describe-cluster \
    --name <CLUSTER_NAME> \
    --region <REGION> \
    --query "cluster.accessConfig.authenticationMode" \
    --output json
```
O retorno será um dos três valores abaixo:
- `CONFIG_MAP`: Modo legado que utiliza exclusivamente o ConfigMap `aws-auth`.
- `API_AND_CONFIG_MAP`: Aceita tanto o ConfigMap quanto as EKS Access Entries (Modelo recomendado para migração).
- `API`: Modo moderno e restrito que ignora o ConfigMap e utiliza exclusivamente as EKS Access Entries.

### 1.5 Listar Access Entries Existentes
```bash
# Listar as entradas de acesso já configuradas
aws eks list-access-entries \
    --cluster-name <CLUSTER_NAME> \
    --region <REGION> \
    --output json
```

---

## PASSO 2: PROCEDIMENTO DE RECUPERAÇÃO DE ACESSO

### MÉTODOLOGO RECOMENDADO: EKS Access Entries (Modo API / API_AND_CONFIG_MAP)
Se o seu cluster suporta o modo API (ou seja, `authenticationMode` está definido como `API_AND_CONFIG_MAP` ou `API`), você pode conceder acesso de forma totalmente nativa pelo IAM/AWS CLI, sem requerer privilégios de `kubectl` existentes.

#### Passo 1: Criar a Entrada de Acesso (Access Entry)
Crie uma entrada vinculando a sua identidade IAM atual (usuário ou role) ao cluster:

```bash
# Criar entrada de acesso para o seu ARN do IAM atual
aws eks create-access-entry \
    --cluster-name <CLUSTER_NAME> \
    --region <REGION> \
    --principal-arn <SEU_IAM_ARN_ATUAL> \
    --output json
```

#### Passo 2: Associar a Política Administrativa do EKS
Associe a política padrão `AmazonEKSClusterAdminPolicy` para conceder acesso de administrador total (cluster-wide) no plano de controle do Kubernetes:

```bash
# Associar política administrativa à entrada de acesso criada
aws eks associate-access-policy \
    --cluster-name <CLUSTER_NAME> \
    --region <REGION> \
    --principal-arn <SEU_IAM_ARN_ATUAL> \
    --policy-arn arn:aws:eks:aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster \
    --output json
```

---

### MÉTODO DE CONTINGÊNCIA: aws-auth ConfigMap (Modo CONFIG_MAP)
Se o cluster operará estritamente no modo `CONFIG_MAP`, a única forma de recuperar acesso é editando o recurso no namespace `kube-system`.

Se ocorreu Lockout total (nenhuma identidade viva tem acesso), siga estes passos para bypassar o bloqueio:
1. **Recriar a identidade original:** Se o criador era um usuário IAM estático deletado, você pode recriar temporariamente um usuário com o **mesmo nome exato** na AWS. O EKS identificará a identidade pelo ARN e restabelecerá o acesso.
2. **Assumir a Role de Automação:** Se o cluster foi criado via CI/CD, configure as credenciais locais usando temporariamente o perfil que o Terraform utiliza para executar.

Uma vez restabelecido o acesso de `kubectl`, execute:

```bash
# Abrir e editar interativamente o ConfigMap de autenticação
kubectl edit configmap aws-auth -n kube-system
```

Insira sua Role ou Usuário administrador atual na estrutura sob a seção `data`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::123456789012:role/SuaRoleSsoAdmin
      username: admin-role
      groups:
        - system:masters
  mapUsers: |
    - userarn: arn:aws:iam::123456789012:user/novo-admin
      username: novo-admin
      groups:
        - system:masters
```
*Salve o arquivo. A sincronização com o EKS é imediata.*

---

## PASSO 3: REFATORAÇÃO DA AUTOMAÇÃO E DO MAKEFILE

Implementamos uma automação local robusta para prevenir problemas silenciosos e guiar o desenvolvedor passo a passo.

### 3.1 Script de Configuração de Contexto (`scripts/configure-kubeconfig.sh`)

Crie o arquivo `scripts/configure-kubeconfig.sh` com o conteúdo abaixo:

```bash
#!/usr/bin/env bash
# ==============================================================================
# Script: scripts/configure-kubeconfig.sh
# Descrição: Validação de perfil AWS, configuração de kubeconfig e teste de conexão.
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações padrões (pode herdar do ambiente)
CLUSTER_NAME="${CLUSTER_NAME:-template-eks-cluster-dev}"
REGION="${AWS_REGION:-us-east-1}"
PROFILE="${AWS_PROFILE}"

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}        Configuração Automática do Kubeconfig${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

# 1. Verificar dependências
if ! command -v aws &>/dev/null; then
    echo -e "${RED}[ERRO] AWS CLI não foi encontrada no PATH. Instale-a antes de continuar.${NC}"
    exit 1
fi

if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}[ERRO] kubectl não foi encontrado no PATH. Instale-o antes de continuar.${NC}"
    exit 1
fi

# 2. Validar autenticação e perfil ativo
echo -e "${BLUE}[INFO] Validando identidade ativa no AWS IAM...${NC}"
AWS_ARGS=()
if [ -n "$PROFILE" ]; then
    AWS_ARGS+=(--profile "$PROFILE")
    echo -e "  -> Usando Perfil AWS: ${YELLOW}$PROFILE${NC}"
fi

if ! CALLER_IDENTITY=$(aws sts get-caller-identity "${AWS_ARGS[@]}" --region "$REGION" 2>/dev/null); then
    echo -e "${RED}[ERRO] Não foi possível autenticar na AWS com o perfil atual.${NC}"
    echo -e "${YELLOW}[DICA] Execute 'make config aws' ou valide suas credenciais SSO executando: aws sso login --profile ${PROFILE:-default}${NC}"
    exit 1
fi

# Resgata o ARN e Conta usando queries nativas e seguras da AWS CLI (evitando dependências de grep/jq)
ARN=$(aws sts get-caller-identity --query "Arn" --output text "${AWS_ARGS[@]}" --region "$REGION" 2>/dev/null || true)
ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text "${AWS_ARGS[@]}" --region "$REGION" 2>/dev/null || true)

echo -e "${GREEN}[OK] Identidade AWS Confirmada!${NC}"
echo -e "  - Conta AWS: ${YELLOW}$ACCOUNT${NC}"
echo -e "  - IAM Principal ARN: ${YELLOW}$ARN${NC}\n"

# 3. Atualizar kubeconfig
echo -e "${BLUE}[INFO] Atualizando arquivo ~/.kube/config para o cluster: ${YELLOW}$CLUSTER_NAME${NC}...${NC}"
if ! aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" "${AWS_ARGS[@]}" &>/dev/null; then
    echo -e "${RED}[ERRO] Falha ao atualizar o kubeconfig via AWS CLI.${NC}"
    echo -e "${YELLOW}[DICA] Verifique se o nome do cluster '$CLUSTER_NAME' e a região '$REGION' estão corretos na sua conta.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Arquivo Kubeconfig atualizado com sucesso!${NC}\n"

# 4. Validar conexão com o cluster tratando erros de RBAC
echo -e "${BLUE}[INFO] Testando comunicação ativa com o cluster via 'kubectl'...${NC}"
KUBECTL_ERROR=$(mktemp)

if kubectl get nodes &>/dev/null 2>"$KUBECTL_ERROR"; then
    echo -e "${GREEN}=====================================================${NC}"
    echo -e "${GREEN}[SUCESSO] Conexão com o cluster Kubernetes estabelecida!${NC}"
    echo -e "${GREEN}Você possui acesso de leitura completo e seu contexto local está pronto.${NC}"
    echo -e "${GREEN}=====================================================${NC}"
    rm -f "$KUBECTL_ERROR"
    exit 0
else
    ERROR_MSG=$(cat "$KUBECTL_ERROR")
    rm -f "$KUBECTL_ERROR"

    echo -e "${RED}[FALHA] Não foi possível obter resposta autorizada do cluster Kubernetes.${NC}"

    if [[ "$ERROR_MSG" == *"Unauthorized"* ]] || [[ "$ERROR_MSG" == *"You must be logged in to the server"* ]] || [[ "$ERROR_MSG" == *"Access Denied"* ]]; then
        echo -e "\n${RED}-----------------------------------------------------${NC}"
        echo -e "${RED}ERRO DETECTADO: Falha de Autenticação / RBAC do EKS${NC}"
        echo -e "${RED}-----------------------------------------------------${NC}"
        echo -e "${YELLOW}Detalhes Técnicos do kubectl:${NC}\n$ERROR_MSG"
        echo -e "\n${YELLOW}CAUSA PROVÁVEL:${NC}"
        echo -e "Sua entidade IAM principal (${ARN}) foi autenticada pela AWS, mas não possui permissões associadas dentro do cluster Kubernetes (via EKS Access Entries ou aws-auth ConfigMap)."
        echo -e "\n${BLUE}COMO CORRIGIR:${NC}"
        echo -e "Solicite ao administrador do Cloud que execute os seguintes comandos na conta para registrar seu acesso:"
        echo -e "  1. aws eks create-access-entry --cluster-name $CLUSTER_NAME --principal-arn $ARN"
        echo -e "  2. aws eks associate-access-policy --cluster-name $CLUSTER_NAME --principal-arn $ARN --policy-arn arn:aws:eks:aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster"
    else
        echo -e "${YELLOW}[ERRO DESCONHECIDO] Verifique sua conexão de rede ou VPN:${NC}\n$ERROR_MSG"
    fi
    exit 1
fi
```

### 3.2 Integração com o `Makefile`

Modifique o seu arquivo `Makefile` na raiz do repositório para expor e integrar a automação de contexto:

```makefile
# ==============================================================================
# Targets de Automação de Configuração do Kubernetes
# ==============================================================================

.PHONY: config-kube

# Alvo principal para o desenvolvedor carregar suas credenciais de contexto do EKS
config-kube:
	@chmod +x scripts/configure-kubeconfig.sh
	@./scripts/configure-kubeconfig.sh
```

---

## 4. BOAS PRÁTICAS DE SEGURANÇA E PREVENÇÃO DE PROBLEMAS

Para evitar que problemas de Lockout voltem a ocorrer e para alinhar seu cluster com as melhores práticas recomendadas pela AWS:

### 4.1 Por que não usar Contas Temporárias, Individuais ou o Root para Criação do Cluster?
- **Imutabilidade Oculta:** O criador do cluster possui permissões permanentes ocultas. Se uma conta raiz ou temporária de pipeline criar o cluster e sumir, os administradores perdem a capacidade de interagir com o Kubernetes control plane.
- **Risco de Session Lockout:** Usar roles temporárias assumidas por pipelines sem configurar imediatamente um backup persistente causa o bloqueio permanente das execuções seguintes do CI/CD.

### 4.2 Recomendações de Governança e Arquitetura de Acesso

1. **Provisionamento via IAM Role Dedicada (IaC):**
   - Garanta que o cluster EKS seja criado de forma automatizada por ferramentas de IaC (ex: Terraform/OpenTofu) rodando com uma IAM Role de infraestrutura dedicada e estável (ex: `DeploymentAutomationRole`).
   - Essa role servirá de chave mestra permanente de emergência.

2. **Adoção Exclusiva das EKS Access Entries:**
   - Evite o ConfigMap `aws-auth` legado. Ele é complexo, de difícil manutenção declarativa e sujeito a falhas graves de formatação.
   - Configure o EKS no Terraform habilitando o modo de suporte nativo API:
     ```hcl
     # Exemplo de configuração de cluster EKS com Access Entries via Terraform
     resource "aws_eks_cluster" "example" {
       name     = "my-eks-cluster"
       role_arn = aws_iam_role.cluster.arn

       access_config {
         authentication_mode                         = "API_AND_CONFIG_MAP"
         bootstrap_cluster_creator_admin_permissions = true
       }
     }
     ```

3. **Mapeamento Explícito de Perfis por Função (SSO/Federação):**
   - Não configure usuários IAM físicos no cluster. Mapeie diretamente os ARNs de perfis federados (Roles do AWS IAM Identity Center/SSO) para papéis adequados de visualização, desenvolvimento ou administração no cluster.
