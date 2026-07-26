# ADR 0005: Automação Unificada de Onboarding Multicloud e OIDC Bootstrap (`make config`)

## Status

Aprovado

## Contexto

Atualmente, o processo de inicialização de infraestrutura em novas contas (AWS e GCP) exige etapas manuais repetitivas para estabelecer a cadeia de confiança via OIDC (OpenID Connect na AWS e Workload Identity Federation na GCP) com o GitHub Actions.

Identificamos dois cenários críticos onde o desenvolvedor precisa de previsibilidade e mínima intervenção manual:

1. **Cenário Day 0 (Conta Nova):** Nenhuma infraestrutura existe. O desenvolvedor possui apenas acesso administrativo básico via CLI (AWS SSO / GCP Application Default Credentials).
2. **Cenário Pós-Clean-Slate (Recuperação):** Toda a infraestrutura gerenciada foi destruída. É necessário restaurar o OIDC, os perfis de acesso do CI/CD e as segredos do GitHub sem reescrever configurações do zero.

Para eliminar a necessidade de criar manualmente usuários IAM, grupos ou Service Accounts no console web de cada cloud provider, precisamos expandir o escopo do comando `make config` para funcionar como um **Orquestrador de Bootstrapping Multicloud**.

---

## Decisão

Adotamos a padronização do comando `make config` (e seus alvos filhos `make config-aws`, `make config-gcp`, `make config-all`) para automatizar **100% da camada de identidade OIDC, backends de estado remoto e injeção de segredos no GitHub**.

### 1. Divisão de Responsabilidades: O que permanece manual vs O que o `make config` automatiza

```
[ Pré-requisito Único (Manual) ]
  ├── AWS:  Login no AWS SSO / Identity Center ('aws sso login')
  └── GCP:  Login no GCP CLI ('gcloud auth application-default login')
                             │
                             ▼
[ Automação Total: 'make config' ]
  ├── 1. Validação de Ferramentas (aws, gcloud, tofu/terraform, gh)
  ├── 2. Provisionamento do Backend de State (S3 + DynamoDB / GCP Bucket)
  ├── 3. Execução do Bootstrap OIDC (OpenTofu)
  │      ├── AWS: OIDC Provider + IAM Roles para GitHub Actions
  │      └── GCP: Workload Identity Pool + Provider + Service Account + IAM Bindings
  └── 4. Sincronização Automática com GitHub (gh secret set)
```

---

### 2. Mapeamento de Cenários de Execução

#### Cenário A: Day 0 (Conta Zerada)

* **Estado Inicial:** Apenas credenciais administrativas locais ativas. Nenhum bucket de estado, Role IAM ou Service Account existente.
* **Comando executado:** `make config-all`
* **Comportamento do `make config`:**
1. Detecta que o backend S3 / GCP Storage não existe e o cria via scripts locais idempotentes (`scripts/setup-backend-aws.sh` e `scripts/setup-backend-gcp.sh`).
2. Aplica o módulo `terraform/bootstrap`, que provisiona declarativamente:
   * **AWS:** OIDC Identity Provider para `token.actions.githubusercontent.com` e Roles de IAM com políticas restritas ao repositório.
   * **GCP:** Workload Identity Pool, Workload Identity Provider e Service Account com permissões no projeto.
3. Coleta os ARNs (AWS) e Emails/Provider IDs (GCP) gerados e atualiza automaticamente os segredos do repositório no GitHub via CLI (`gh secret set`).

#### Cenário B: Pós-Clean-Slate (Reconstrução)

* **Estado Inicial:** Infraestrutura das aplicações removida, mas o backend de estado ou os acessos administrativos continuam operacionais.
* **Comando executado:** `make config-all` (ou `make config-aws` / `make config-gcp` separadamente)
* **Comportamento do `make config`:**
1. Identifica os recursos do bootstrap existentes ou realiza o `tofu apply` delta em `terraform/bootstrap`.
2. Garante que os tokens OIDC e segredos do GitHub estejam sincronizados e válidos.
3. Deixa o ambiente 100% pronto para que o próximo `git push` ou disparo manual no GitHub Actions re-provisione o cluster Kubernetes (EKS/GKE), VPCs e recursos de aplicação de forma limpa.

---

### 3. Interface de Comandos Padronizada (`Makefile`)

Abaixo está o fluxo lógico de execução que o `Makefile` adota:

```bash
# Executa verificação e setup completo (AWS + GCP)
make config

# Ou de forma explícita por provedor:
make config-aws
make config-gcp
```

#### Sequência Interna do Script de Automação (`scripts/bootstrap-multicloud.sh`):

```bash
#!/usr/bin/env bash
set -e

echo "=== [1/4] Verificando dependências de CLI (aws, gcloud, tofu, gh) ==="
# Valida se o usuário está autenticado na AWS e GCP
aws sts get-caller-identity > /dev/null || { echo "Erro: Faça 'aws sso login' primeiro."; exit 1; }
gcloud auth print-access-token > /dev/null || { echo "Erro: Faça 'gcloud auth application-default login' primeiro."; exit 1; }

echo "=== [2/4] Garantindo Backends de Estado (S3 / GCS) ==="
bash scripts/setup-backend-aws.sh
bash scripts/setup-backend-gcp.sh

echo "=== [3/4] Provisionando OIDC AWS & Workload Identity Federation GCP ==="
cd terraform/bootstrap
tofu init -upgrade
tofu apply -auto-approve \
  -var="github_org_repo=${GITHUB_REPOSITORY}" \
  -var="gcp_project_id=${GCP_PROJECT_ID}"

AWS_ROLE_ARN=$(tofu output -raw github_actions_aws_role_arn)
GCP_SA_EMAIL=$(tofu output -raw github_actions_gcp_sa_email)
GCP_WIF_PROVIDER=$(tofu output -raw gcp_workload_identity_provider)
cd -

echo "=== [4/4] Atualizando GitHub Secrets via 'gh' CLI ==="
gh secret set AWS_ROLE_ARN -b"${AWS_ROLE_ARN}"
gh secret set GCP_SA_EMAIL -b"${GCP_SA_EMAIL}"
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER -b"${GCP_WIF_PROVIDER}"

echo "=== BOOTSTRAP MULTICLOUD CONCLUÍDO COM SUCESSO! ==="
```

---

## Consequências

### Ganhos

* **Zero Intervenção em Consoles Web:** Não há necessidade de clicar na interface da AWS para criar IAM Users/Groups ou na GCP para criar Service Accounts e chaves JSON estáticas.
* **Segurança Baseada em OIDC:** Ausência total de credenciais estáticas (`AWS_ACCESS_KEY_ID` ou arquivos JSON da GCP) salvas no GitHub Secrets.
* **Idempotência:** O comando `make config` pode ser executado *n* vezes sem quebrar o ambiente, seja no Day 0 ou após um Clean Slate.

### Requisitos Próximos

1. Manter o módulo `terraform/bootstrap` cobrindo declarativamente tanto os recursos de OIDC da AWS quanto o Workload Identity Pool da GCP.
2. Garantir que a CLI do GitHub (`gh`) esteja autenticada no ambiente do desenvolvedor (`gh auth login`).
