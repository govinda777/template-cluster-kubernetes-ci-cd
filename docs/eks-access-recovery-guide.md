# Guia de Investigação, Recuperação de Acesso e Melhores Práticas: Amazon EKS IAM

## Autor: Engenheiro Principal de Cloud e Kubernetes
**Assunto:** Recuperação de acesso de administração ao cluster Amazon EKS e migração para o modelo de autenticação moderno (EKS Access Entries).

---

## INTRODUÇÃO E CAUSA RAIZ

### Por que o erro acontece?
Por padrão, quando um cluster Amazon EKS é criado, a entidade principal do IAM (usuário ou perfil/role) que cria o cluster recebe automaticamente permissões de administrador (`system:masters`) no painel de controle do Kubernetes (RBAC).

No entanto, **essa permissão é implícita e invisível**:
- Ela **não** aparece no `configmap/aws-auth` no namespace `kube-system`.
- Ela **não** aparece nas políticas normais do IAM anexadas ao seu usuário atual.
- Se o usuário ou role original do IAM for excluído, desativado ou se suas credenciais forem perdidas, **nenhuma outra entidade do IAM** (mesmo o usuário Root da conta AWS ou um administrador com políticas `AdministratorAccess` completas no IAM) terá acesso padrão para ler ou interagir com os objetos do Kubernetes através da API do cluster (`kubectl`) ou do Console da AWS.

Isso gera a famosa mensagem de erro no Console da AWS:
> *"A entidade principal do IAM atual não tem acesso a objetos do Kubernetes neste cluster..."*

Abaixo, apresentamos o guia prático passo a passo de como investigar a identidade criadora, como recuperar o acesso usando as funcionalidades modernas e como estruturar a automação local.

---

## 1. INVESTIGAÇÃO DO ESTADO ATUAL DO IAM E DO EKS

Antes de fazer alterações, é crucial mapear o estado do cluster, as identidades ativas e o modo de autenticação do EKS.

### 1.1 Listar Usuários e Roles do IAM Atuais na Conta
Para entender quais identidades existem no ambiente e validar se o usuário antigo/suspeito (ex: `admin`) ainda existe:

```bash
# Listar todos os usuários do IAM para verificar se o criador antigo ainda existe
aws iam list-users --query "Users[].UserName" --output table

# Listar todas as roles/perfis do IAM na conta
aws iam list-roles --query "Roles[].RoleName" --output table
```

### 1.2 Identificar Quem Criou o Cluster EKS
Se o usuário antigo não está nas listas anteriores, ele foi excluído. Para confirmar o ARN exato do criador original do cluster, você pode consultar o AWS CloudTrail ou verificar as tags do cluster.

#### Opção A: Consulta via CloudTrail (Eventos de Criação)
A API de criação do cluster gera um evento `CreateCluster`. Podemos extrair quem efetuou a chamada:

```bash
# Consultar o evento 'CreateCluster' nos últimos 90 dias para obter o ARN do criador original
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventName,AttributeValue=CreateCluster \
    --query "Events[].{Time: EventTime, Principal: Username, EventData: CloudTrailEvent}" \
    --output json
```
*(No JSON retornado, procure no campo `EventData` o bloco `userIdentity` para ver o ARN completo da entidade original).*

#### Opção B: Verificação rápida por Tags
Frequentemente, ferramentas de IaC adicionam a tag do criador ao recurso:
```bash
# Substitua <CLUSTER_NAME> e <REGION> pelos seus valores reais
aws eks describe-cluster \
    --name <CLUSTER_NAME> \
    --region <REGION> \
    --query "cluster.tags" \
    --output json
```

### 1.3 Verificar o Modo de Autenticação (`authenticationMode`)
O EKS suporta dois modos de autenticação principal. O modelo moderno do EKS permite migrar e delegar totalmente o controle para políticas IAM nativas.

```bash
# Verificar se o cluster usa CONFIG_MAP, API_AND_CONFIG_MAP ou API
aws eks describe-cluster \
    --name <CLUSTER_NAME> \
    --region <REGION> \
    --query "cluster.accessConfig.authenticationMode" \
    --output json
```

### 1.4 Listar as Access Entries Existentes no Cluster
Se o cluster já estiver configurado para aceitar a API de acesso (`API` ou `API_AND_CONFIG_MAP`), podemos listar as entradas registradas:

```bash
# Listar todas as Access Entries registradas no EKS
aws eks list-access-entries \
    --cluster-name <CLUSTER_NAME> \
    --region <REGION> \
    --output json
```

---

## 2. CORREÇÃO E RECUPERAÇÃO DO ACESSO AO CLUSTER

### Método Principal: EKS Access Entries (Modelo Moderno - Recomendado)
Se o cluster EKS estiver rodando com o `authenticationMode` configurado como `API_AND_CONFIG_MAP` ou `API`, você pode conceder permissões administrativas diretamente via AWS CLI, sem precisar de acesso prévio via `kubectl`.

#### Passo 1: Obter o seu ARN do IAM Atual
Execute o comando abaixo para obter o ARN da entidade principal que você está utilizando no momento (sua Role SSO ou usuário Admin atual):
```bash
aws sts get-caller-identity --query "Arn" --output text
```
*Exemplo de retorno:* `arn:aws:iam::123456789012:user/novo-admin` ou `arn:aws:sts::123456789012:assumed-role/AWSReservedSSO_AdministratorAccess_xxx/meu-usuario`

#### Passo 2: Criar a Access Entry para a sua Entidade IAM
Associe a sua identidade atual ao cluster EKS:
```bash
# Criar uma entrada de acesso para o seu ARN atual
aws eks create-access-entry \
    --cluster-name <CLUSTER_NAME> \
    --region <REGION> \
    --principal-arn <SEU_IAM_ARN_ATUAL> \
    --output json
```

#### Passo 3: Associar a Política de Administração do EKS
Associe a política interna `AmazonEKSClusterAdminPolicy` para garantir direitos totais de gerenciamento de RBAC no Kubernetes:
```bash
# Associar a política de administração do cluster para a sua entrada de acesso
aws eks associate-access-policy \
    --cluster-name <CLUSTER_NAME> \
    --region <REGION> \
    --principal-arn <SEU_IAM_ARN_ATUAL> \
    --policy-arn arn:aws:eks:aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster \
    --output json
```

---

### Método de Contingência: Modelo Legado (`CONFIG_MAP`)
Se o cluster estiver operando **apenas** em modo `CONFIG_MAP` e você não conseguir criar Access Entries diretamente, é necessário editar o ConfigMap `aws-auth` no namespace `kube-system`.

Se você perdeu completamente o acesso de administração (`kubectl`), você precisará **assumir temporariamente uma entidade que possua acesso** (ou recriar o usuário IAM antigo com o mesmo nome exato caso ele tenha sido excluído, para que o EKS o reconheça pelo ARN).

Assim que recuperar o acesso de forma temporária, execute a edição do ConfigMap:

```bash
# Abrir o configmap aws-auth em modo de edição interativa
kubectl edit configmap aws-auth -n kube-system
```

No campo `mapUsers` ou `mapRoles`, adicione a sua entidade atual conforme a estrutura abaixo:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::123456789012:role/MinhaRoleAdministradora
      username: admin-role
      groups:
        - system:masters
  mapUsers: |
    - userarn: arn:aws:iam::123456789012:user/novo-admin
      username: novo-admin
      groups:
        - system:masters
```
*Salve e feche o arquivo para aplicar a alteração instantaneamente.*

---

## 3. REVISÃO E MELHORIA DA AUTOMAÇÃO LOCAL (`make config` / Makefile)

Para garantir que novos engenheiros ou desenvolvedores configurem o acesso local de forma segura, rápida e sem erros silenciosos, implementamos uma automação completa.

### 3.1 Script de Automação de Contexto (`scripts/configure-kubeconfig.sh`)
Crie este script para validar o perfil, atualizar as credenciais do cluster e testar a conexão tratando potenciais erros de RBAC.

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

# 1. Verificar se a AWS CLI está instalada
if ! command -v aws &>/dev/null; then
    echo -e "${RED}[ERRO] AWS CLI não foi encontrada no PATH. Instale-a antes de continuar.${NC}"
    exit 1
fi

# 2. Verificar se o kubectl está instalado
if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}[ERRO] kubectl não foi encontrado no PATH. Instale-o antes de continuar.${NC}"
    exit 1
fi

# 3. Validar a identidade do chamador AWS
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

ARN=$(echo "$CALLER_IDENTITY" | grep -o '"Arn": "[^"]*' | grep -o '[^"]*$')
ACCOUNT=$(echo "$CALLER_IDENTITY" | grep -o '"Account": "[^"]*' | grep -o '[^"]*$')

echo -e "${GREEN}[OK] Identidade AWS Confirmada!${NC}"
echo -e "  - Conta AWS: ${YELLOW}$ACCOUNT${NC}"
echo -e "  - IAM Principal ARN: ${YELLOW}$ARN${NC}\n"

# 4. Atualizar o arquivo ~/.kube/config
echo -e "${BLUE}[INFO] Atualizando arquivo ~/.kube/config para o cluster: ${YELLOW}$CLUSTER_NAME${NC}...${NC}"
if ! aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" "${AWS_ARGS[@]}" &>/dev/null; then
    echo -e "${RED}[ERRO] Falha ao atualizar o kubeconfig via AWS CLI.${NC}"
    echo -e "${YELLOW}[DICA] Verifique se o nome do cluster '$CLUSTER_NAME' e a região '$REGION' estão corretos na sua conta.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Arquivo Kubeconfig atualizado com sucesso!${NC}\n"

# 5. Validar conexão com o cluster tratando erros de RBAC
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

### 3.2 Integração no `Makefile`
Para garantir uma experiência de desenvolvimento simplificada, integre o script acima ao alvo `make config` do `Makefile`:

```makefile
# Alvo para configurar o contexto local do Kubernetes
config-kube:
	@chmod +x scripts/configure-kubeconfig.sh
	@./scripts/configure-kubeconfig.sh
```

---

## 4. MELHORES PRÁTICAS DE SEGURANÇA E GESTÃO DE ACESSO (EKS)

Como Engenheiro Principal, o gerenciamento de acesso ao EKS deve seguir as diretrizes rígidas do Well-Architected Framework da AWS e os princípios de menor privilégio:

### 4.1 Por que NUNCA usar Usuários Root, Individuais ou Credenciais Temporárias de Curto Prazo para Criar clusters?
1. **O Criador Oculto Imutável:** A entidade que cria o cluster ganha acesso de administrador invisível permanente que não pode ser facilmente auditado ou removido se for uma conta raiz (`root`).
2. **Perda de Rastreabilidade:** Se um usuário individual (ex: `admin-joao`) cria o cluster e sai da empresa, o acesso global pode ser interrompido e as credenciais excluídas do IAM causarão falhas de reconfiguração de automações secundárias.
3. **Credenciais Temporárias de CI/CD (Risco de Lockout):** Se você usar uma IAM Role temporária gerada dinamicamente em um pipeline para criar o cluster sem configurar explícita e imediatamente outras entidades persistentes no `aws-auth` ou Access Entries, o acesso de administração ao cluster ficará preso ao ID dinâmico da sessão STS daquele exato momento, tornando o cluster inacessível em execuções de pipelines futuras.

### 4.2 Padrão Recomendado de Arquitetura de Acesso
O padrão ouro de governança do EKS estrutura o acesso em três camadas robustas:

```text
               +----------------------------------+
               |        AWS Identity Center       |  <-- SSO Centralizado
               +----------------------------------+
                                │
          ┌─────────────────────┴─────────────────────┐
          ▼                                           ▼
+-----------------------+                   +--------------------+
|  Role Admin EKS (SSO) |                   |  Role Dev EKS (SSO)|
+-----------------------+                   +--------------------+
          │                                           │
          ▼                                           ▼
+----------------------------------------------------------------+
|                   Amazon EKS Access Entries                    |
+----------------------------------------------------------------+
          │                                           │
          ▼ (AmazonEKSClusterAdminPolicy)             ▼ (AmazonEKSAdminViewPolicy / Custom Namespace Policy)
+-----------------------------------+       +------------------------------------+
|  Acesso Total Cluster-Wide (RBAC) |       | Acesso Somente Leitura/Restrito    |
+-----------------------------------+       +------------------------------------+
```

#### 1. Provedor de Identidade Único (IdP / AWS SSO)
- Todas as credenciais de usuários físicos devem ser gerenciadas via **AWS IAM Identity Center** (anteriormente AWS SSO) ou federação corporativa via OIDC (ex: Okta, Azure AD).
- **Sem chaves de acesso estáticas (`AKIA`)** em computadores de desenvolvedores.

#### 2. Criação do Cluster via IaC com IAM Role Dedicada
- O cluster deve ser criado de forma programática usando **Terraform/OpenTofu**.
- O executor do Terraform deve utilizar uma **IAM Role dedicada para Automação** (ex.: `EKS-Cluster-Creator-Role`), nunca credenciais de indivíduos.
- Essa Role deve ter seu ARN guardado e monitorado, servindo como a "chave mestra" de contingência do cluster.

#### 3. Substituição Imediata do `aws-auth` ConfigMap por EKS Access Entries
- O ConfigMap `aws-auth` legado em formato YAML é propenso a erros de sintaxe manual que podem quebrar a autenticação de todo o cluster.
- Utilize a nova funcionalidade **EKS Access Entries** gerenciando os privilégios de acesso do cluster declarativamente como recursos nativos da AWS (IaC) e delegando o RBAC para as políticas pré-definidas da AWS:
  - `AmazonEKSClusterAdminPolicy`: Controle total do cluster (Administrador).
  - `AmazonEKSAdminPolicy`: Permissões administrativas dentro de namespaces específicos.
  - `AmazonEKSViewerPolicy`: Acesso de visualização a recursos Kubernetes.
