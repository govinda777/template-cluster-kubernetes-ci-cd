# Integração de Autenticação Segura: Google Cloud Platform (GCP) & Workload Identity Federation

Este documento descreve detalhadamente a arquitetura, o fluxo de execução, a configuração e o monitoramento da autenticação dinâmica entre as ferramentas de CI/CD (GitHub Actions), o cliente gcloud CLI local e as APIs do Google Cloud Platform (GCP).

Essa solução adota o **Workload Identity Federation (WIF)**, eliminando completamente a necessidade de chaves de acesso estáticas, senhas ou arquivos JSON de credenciais de longa duração (`Service Account Keys`) dentro do repositório GitHub.

---

## 1. Visão Geral e Arquitetura

Tradicionalmente, a autenticação de pipelines ou ferramentas externas com o GCP dependia da criação e exportação de uma chave de Service Account em formato JSON, a qual era armazenada nos segredos dos pipelines. Essa prática acarreta riscos elevados de vazamento acidental, rotação manual custosa e quebra do princípio de privilégio mínimo.

Com o **Workload Identity Federation**, o GitHub Actions autentica-se diretamente no Google Cloud utilizando tokens OpenID Connect (OIDC) de curta duração gerados de forma nativa e sob demanda pelo GitHub.

### Fluxo de Autenticação Dinâmica (WIF / OIDC)

Quando uma ação ou ferramenta local solicita acesso ao GCP via WIF, o seguinte fluxo ocorre em segundo plano:

```
+----------------+          1. Solicita ID Token OIDC        +--------------------+
| GitHub Actions | ----------------------------------------> | GitHub OIDC Token  |
|   Workflow     | <---------------------------------------- |     Service        |
+----------------+          2. Devolve JWT assinado          +--------------------+
        |
        | 3. Envia JWT (OIDC assertion) para as APIs do GCP
        v
+------------------------------------+
| GCP Security Token Service (STS)   |
+------------------------------------+
        |
        | 4. Valida assinatura do JWT com o emissor do GitHub
        v
+------------------------------------+
| Workload Identity Pool / Provider  |
+------------------------------------+
        |
        | 5. Gera token federado do GCP (Federated Token)
        v
+------------------------------------+
| GCP IAM (Impersonate Service Acct) |
+------------------------------------+
        |
        | 6. Devolve Access Token temporário do GCP (máx. 1 hora)
        v
+------------------------------------+          7. Provisiona recursos
|   Google Cloud Provider / APIs     | --------------------------------------> GCP Project
+------------------------------------+
```

1. **Geração de Token pelo GitHub:** O GitHub Actions gera um JWT OIDC criptograficamente assinado com os metadados do workflow (repositório, branch, run ID, actor).
2. **Troca no STS do GCP:** O pipeline envia esse token ao endpoint de Security Token Service (STS) do GCP.
3. **Validação e Pool:** O STS valida a assinatura digital e as condições definidas no Workload Identity Pool Provider (ex: garantir que a requisição partiu do repositório `owner/repo`).
4. **Geração de Token do GCP:** O GCP STS gera um token federado de curta duração.
5. **Impersonação de Service Account:** O token federado é utilizado para realizar a impersonação da Service Account do GCP selecionada (ex: `github-actions-dev-sa`), devolvendo um `access_token` padrão do GCP válido por no máximo 1 hora.
6. **Execução de IaC:** O pipeline utiliza esse token para realizar o provisionamento seguro dos recursos via OpenTofu/Terraform.

---

## 2. Geração de Credenciais Temporárias e Segurança

Ao utilizar o WIF, **nunca** há armazenamento persistente de segredos de acesso ao GCP.

### Atributos e Filtros de Segurança (Claims Mapping)

As regras de confiança especificadas em nosso bootstrap garantem que somente o nosso repositório tenha acesso para impersonar as Service Accounts correspondentes. No GCP, isso é mapeado da seguinte forma:

- `google.subject` = `assertion.sub` (identificador exclusivo da branch/ambiente)
- `attribute.repository` = `assertion.repository` (formato: `owner/repo`)
- `attribute.repository_owner` = `assertion.repository_owner` (formato: `owner`)

A política de impersonação da Service Account (`roles/iam.workloadIdentityUser`) é vinculada à condição exata do repositório correspondente:
```text
principalSet://iam.googleapis.com/projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/owner/repo
```

Desta forma, mesmo que outro usuário ou repositório tente requisitar acesso ao Pool usando OIDC do GitHub, o GCP rejeitará a solicitação devido ao filtro rígido do atributo de repositório.

---

## 3. Pré-requisitos da Máquina Local

Para que a autenticação local funcione e para rodar o bootstrap, sua máquina de desenvolvimento precisa de:

* **Git (v2.20+)**
* **GitHub CLI (`gh`)**
* **OpenTofu ou Terraform**
* **Google Cloud SDK (gcloud CLI)**
* **GNU Make**

---

## 4. O Comando `make config-gcp`

O atalho `make config-gcp` (ou `make config gcp`) invoca o script automatizado localizado em `scripts/config-gcp.sh`. Esse script executa as seguintes tarefas:

1. **Auto-instalação de Dependências:** Detecta o sistema operacional (Linux ou macOS) e instala automaticamente o Git, GitHub CLI (`gh`), OpenTofu (`tofu`) e Google Cloud SDK se não estiverem presentes no sistema.
2. **Autenticação CLI & ADC:** Guia o usuário interativamente para realizar o login do usuário no gcloud (`gcloud auth login`) e nas Application Default Credentials (`gcloud auth application-default login`), garantindo que o OpenTofu local consiga se conectar e provisionar recursos do GCP.
3. **Persistência de Configurações:** Grava as variáveis `GCP_PROJECT_ID`, `GCP_REGION` e `GCP_ZONE` no arquivo local `.gcp_profile_env` (ignorado no git).
4. **Bootstrap OIDC (Opcional):** Permite inicializar e aplicar as regras de IAM e WIF na nuvem via OpenTofu em `terraform/bootstrap`, salvando os identificadores e e-mails resultantes diretamente nos GitHub Secrets do repositório através do `gh secret set`.

### Variáveis Salvas no GitHub Secrets

Após o bootstrap, as seguintes variáveis serão configuradas no repositório GitHub para uso imediato pelo pipeline:
- `GCP_PROJECT_ID`: O ID do projeto ativo.
- `GCP_REGION`: A região ativa (ex: `us-central1`).
- `GCP_WORKLOAD_IDENTITY_PROVIDER`: O caminho completo do provedor WIF (ex: `projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`).
- `GCP_SERVICE_ACCOUNT_DEV`: O e-mail da SA de Dev (`github-actions-dev-sa@<project>.iam.gserviceaccount.com`).
- `GCP_SERVICE_ACCOUNT_PROD`: O e-mail da SA de Prod (`github-actions-prod-sa@<project>.iam.gserviceaccount.com`).
- `GCP_SERVICE_ACCOUNT_TEST`: O e-mail da SA de Test (`github-actions-test-sa@<project>.iam.gserviceaccount.com`).

---

## 5. Guia Passo a Passo para Novos Desenvolvedores

### Passo 1: Clonar o Repositório do Projeto
```bash
git clone <URL_REPOSITORIO>
cd template-cluster-kubernetes-ci-cd
```

### Passo 2: Executar o Setup de Configuração
```bash
make config gcp
```
Se alguma dependência estiver ausente, ela será instalada automaticamente (no macOS, requer Homebrew; no Linux, requer permissão de `sudo`).

### Passo 3: Concluir Autenticações no Navegador
O script abrirá janelas em seu navegador de internet padrão. Digite suas credenciais corporativas do Google Cloud para autenticar as sessões do gcloud e ADC.

### Passo 4: Definir Project ID, Região e Zona
Siga os prompts inserindo o seu ID do projeto GCP correspondente, região e zona. As configurações serão registradas fisicamente no arquivo local de ambiente `.gcp_profile_env`.

### Passo 5: Testar Conexão e Inicialização do Backend GCS
Para criar ou usar o backend GCS localmente, garanta que os buckets de estado foram devidamente criados usando o script auxiliar de backend:
```bash
bash scripts/setup-backend.sh
```

---

## 6. Governança, Auditoria e Troubleshooting

### Auditoria de Eventos no GCP Cloud Logging

Todas as solicitações de impersonação de Service Account e trocas de token do WIF são gravadas automaticamente no **Cloud Logging** do Google Cloud.

#### Como auditar eventos de autenticação:
1. Acesse o console do GCP e vai em **Logging > Logs Explorer**.
2. Cole a seguinte query estruturada para auditar tentativas de impersonação da Service Account:
   ```text
   protoPayload.methodName="google.iam.v1.IAMCredentials.GenerateAccessToken"
   ```
3. O payload detalhará a identidade do chamador (como o token JWT contendo o repositório GitHub de origem).

---

## 7. Troubleshooting & Erros Comuns

### Erro 1: `Federated token exchange failed` ao rodar o pipeline no GitHub Actions
* **Causa:** O `GCP_WORKLOAD_IDENTITY_PROVIDER` está configurado de forma incorreta ou as permissões de impersonação de SA (`roles/iam.workloadIdentityUser`) não foram corretamente concedidas para a Service Account selecionada no GCP.
* **Resolução:** Certifique-se de que o bootstrap foi executado com sucesso e que o secret `GCP_WORKLOAD_IDENTITY_PROVIDER` aponta para o ID numérico correto do projeto do GCP (ex: `projects/123456789012/...` em vez de `projects/meu-project-id/...`). O OpenTofu resolve isso automaticamente ao coletar a saída no bootstrap.

### Erro 2: `gcloud: command not found` no terminal local
* **Causa:** O gcloud CLI não foi instalado ou seu diretório de instalação não está incluído na variável de ambiente `PATH`.
* **Resolução:** O script `scripts/config-gcp.sh` tenta instalar e configurar o caminho de execução automaticamente. Caso persistir, feche e abra o terminal de comando, ou certifique-se de exportar a pasta de binários do SDK em seu shell rc (`~/.bashrc` ou `~/.zshrc`):
  ```bash
  source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc"
  ```

### Erro 3: `Error acquiring state lock` no OpenTofu local
* **Causa:** Outro membro da equipe está aplicando alterações simultaneamente, ou um processo anterior foi abruptamente encerrado.
* **Resolução:** No backend GCS, o bloqueio (locking) é nativo. Caso queira forçar a remoção de um lock antigo e órfão de sua própria autoria, execute:
  ```bash
  tofu force-unlock <LOCK_ID>
  ```

---

## 8. Guia de Onboarding: Criando uma Conta GCP do Zero (Sem Conta/Projeto Existentes)

Se você é um novo desenvolvedor e ainda **não possui uma conta ou projeto no Google Cloud Platform (GCP)**, siga os passos abaixo para preparar seu ambiente e evitar erros de permissão ou APIs desabilitadas durante o comando `make config-gcp` e o bootstrap.

### Passo 1: Criar sua Conta no Console do GCP
1. Acesse o [Google Cloud Console](https://console.cloud.google.com/).
2. Faça login com sua conta Google (pessoal ou corporativa).
3. Aceite os termos de serviço. Novos usuários geralmente qualificam-se para o **Free Tier** do GCP, recebendo US$ 300 em créditos de teste gratuitos.

### Passo 2: Criar um Projeto GCP
No GCP, todos os recursos (incluindo redes, buckets GCS, WIF e GKE) devem pertencer a um Projeto.
1. No topo da página do Console do GCP, clique no seletor de projetos.
2. Clique em **Novo Projeto** (New Project).
3. Insira um nome descritivo (ex: `k8s-multi-cloud-dev`).
4. O GCP gerará um **Project ID** único (ex: `k8s-multi-cloud-dev-415283`). **Copie este ID**, pois ele será usado em suas variáveis de ambiente e no terminal!

### Passo 3: Ativar o Faturamento (Billing)
Mesmo que você esteja usando créditos gratuitos ou o nível gratuito (Free Tier), o GCP exige que uma conta de faturamento (Billing Account) esteja associada ao projeto para permitir o provisionamento de recursos de infraestrutura pelo Terraform/OpenTofu.
1. No menu lateral esquerdo do Console, vá em **Faturamento** (Billing).
2. Siga as instruções para associar um perfil de faturamento válido ao projeto que você acabou de criar.

### Passo 4: Habilitar as APIs Críticas no Projeto
Por padrão, novos projetos no GCP vêm com a maioria das APIs de serviço desativadas. Para que o bootstrap do OIDC/WIF e a criação de recursos funcionem sem falhas, você **deve habilitar as seguintes APIs** no seu projeto:
1. Vá em **APIs e Serviços > Biblioteca** (APIs & Services > Library) no Console.
2. Busque e ative individualmente as seguintes APIs:
   - **IAM API** (`iam.googleapis.com`) - Para criar Service Accounts e gerenciar permissões.
   - **Security Token Service API** (`sts.googleapis.com`) - Necessária para a troca de tokens do WIF.
   - **Cloud Resource Manager API** (`cloudresourcemanager.googleapis.com`) - Para gerenciar políticas do projeto.
   - **IAM Service Account Credentials API** (`iamcredentials.googleapis.com`) - Para permitir a impersonação de Service Accounts.
   - **Compute Engine API** (`compute.googleapis.com`) - Necessária para redes e recursos de computação do GKE.
   - **Kubernetes Engine API** (`container.googleapis.com`) - Para provisionar o cluster gerenciado GKE.

*Dica de Automação:* Após realizar o login no terminal com `make config-gcp`, você também pode habilitar todas as APIs de uma só vez rodando o seguinte comando no seu terminal:
```bash
gcloud services enable \
    iam.googleapis.com \
    sts.googleapis.com \
    cloudresourcemanager.googleapis.com \
    compute.googleapis.com \
    container.googleapis.com \
    iamcredentials.googleapis.com
```

---

## 9. Como a Pipeline CI/CD lida com GCP sem Credenciais Ativas (O Parâmetro `enable_gke`)

Para evitar falhas na pipeline do GitHub Actions quando as credenciais do Google Cloud ainda não estão configuradas (por exemplo, no onboarding inicial), o projeto utiliza uma flag de controle condicional chamada **`enable_gke`**.

### Como funciona?
Nas pastas `terraform/live/dev/variables.tf` e `terraform/live/prod/variables.tf`, o parâmetro `enable_gke` é definido como `false` por padrão:
```hcl
variable "enable_gke" {
  type        = bool
  description = "Toggle to enable/disable GKE cluster deployment"
  default     = false
}
```

E no arquivo `main.tf` dos ambientes, o módulo do GKE utiliza o parâmetro `count` do Terraform/OpenTofu condicionado a essa variável:
```hcl
module "gke" {
  count        = var.enable_gke ? 1 : 0
  source       = "../../modules/gke"
  ...
}
```

### Vantagens dessa Abordagem:
1. **Pipeline Sempre Verde (Always Green):** Como `enable_gke` é `false` por padrão, a pipeline do GitHub Actions não tenta planejar ou criar recursos do GCP quando iniciada em um repositório que só possui credenciais da AWS. Isso evita erros de `google: could not find default credentials` durante o `tofu plan`.
2. **Onboarding Simplificado:** Novos desenvolvedores podem rodar `tofu apply` para o cluster AWS (EKS) imediatamente.
3. **Ativação Simples:** Assim que você possuir suas credenciais GCP configuradas e tiver feito o bootstrap do OIDC GCP via `make config gcp`, basta ativar a variável alterando o default para `true` ou criando um arquivo `terraform.tfvars` local com:
   ```hcl
   enable_gke = true
   ```
