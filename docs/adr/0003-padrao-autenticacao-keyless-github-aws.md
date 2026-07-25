# ADR-003: Padrão de Autenticação Keyless entre GitHub Actions e AWS para Deploy no EKS/ECR

* **Status:** Aceito
* **Data:** 2026-07-25
* **Decisores:** Arquiteto Principal de Plataforma & Cloud, Equipe de Engenharia de Plataforma e DevOps
* **Contexto Técnico:** Repositório `template-cluster-kubernetes-ci-cd`

---

## Contexto e Declaração do Problema

No ecossistema de Integração e Entrega Contínuas (CI/CD), a autenticação segura do pipeline com os provedores de nuvem é um pilar crítico de segurança. Historicamente, a integração entre o GitHub Actions e a Amazon Web Services (AWS) era realizada por meio da criação de IAM Users dedicados com Access Keys estáticas mantidas nos GitHub Secrets.

Essa abordagem apresenta severos riscos de segurança:
* **Vazamento e Exposição de Credenciais:** As chaves de acesso de longa duração podem ser expostas inadvertidamente em logs do pipeline ou comprometidas por vulnerabilidades na cadeia de suprimentos de software.
* **Gestão Operacional Complexa:** A rotação manual ou automatizada de chaves exige esforço contínuo e gera potenciais pontos de indisponibilidade no fluxo de entrega.
* **Falta de Granularidade e Rastreabilidade:** Dificuldade em associar chamadas de API registradas no AWS CloudTrail a workflows, branches ou execuções específicas de Pull Requests no GitHub.

Para o repositório `template-cluster-kubernetes-ci-cd`, cujo objetivo é automatizar o provisionamento de infraestrutura (Amazon EKS) e a publicação de artefatos (Amazon ECR), é imperativo adotar uma arquitetura de autenticação sem senhas (keyless) federada, 100% declarativa e estritamente alinhada ao Princípio do Menor Privilégio (*Least Privilege*).

---

## Fatores Decisórios (Decision Drivers)

1. **Segurança e Postura Keyless Zero Trust:** Eliminação definitiva de credenciais estáticas de longa duração armazenadas fora do ambiente AWS.
2. **Gestão Declarativa via Infraestrutura como Código (IaC):** Todo o provisionamento do Provedor OIDC e das IAM Roles/Policies deve ser versionado, auditado e aplicado via OpenTofu/Terraform.
3. **Princípio do Menor Privilégio (Least Privilege):** Restrição estrita das permissões IAM para operações em Amazon ECR e Amazon EKS, vinculando a relação de confiança (*Trust Policy*) estritamente à organização, ao repositório, aos ambientes (*dev* vs *prod*) e às branches do GitHub (*main* vs *feature/**).
4. **Rastreabilidade e Auditoria Avançada:** Capacidade de auditabilidade detalhada no AWS CloudTrail associando chamadas a execuções específicas de pipelines por meio das *claims* do JWT emitido pelo GitHub.

---

## Opções Consideradas

### Opção 1: IAM User com Access Keys estáticas salvas no GitHub Secrets
* **Descrição:** Criação de um usuário IAM fixo com chaves de acesso gravadas como segredos no repositório GitHub.
* **Prós:**
  * Baixa complexidade inicial de configuração técnica.
* **Contras:**
  * **Risco Crítico de Segurança:** Credenciais estáticas de longa duração armazenadas fora do controle de identidade nativo da nuvem.
  * Necessidade de implementar rotinas complexas para rotação periódica de chaves.
  * Incompatibilidade com as diretrizes modernas de engenharia de segurança em nuvem e compliance corporativo.

### Opção 2: Provisionamento de OIDC e IAM Roles via Scripts Bash / AWS CLI (Imperativo)
* **Descrição:** Configuração da federação OIDC e papéis IAM executada via scripts imperativos em AWS CLI ou Shell scripts.
* **Prós:**
  * Implementa a autenticação federada OIDC sem chaves estáticas.
* **Contras:**
  * Ausência de controle de estado (*state drift*) e falta de idempotência garantida.
  * Acoplamento com execuções manuais e quebra de padronização corporativa do ecossistema IaC do repositório.
  * Dificuldade de auditoria e revisão de código via Pull Requests.

### Opção 3: Provisionamento de OIDC e IAM Roles via Terraform (Declarativo / IaC)
* **Descrição:** Criação declarativa do Provedor OIDC do GitHub e das IAM Roles/Policies parametrizadas via OpenTofu/Terraform no repositório.
* **Prós:**
  * **Automação 100% Declarativa:** Totalmente integrado com o fluxo de IaC do projeto e gerenciado no backend remoto S3 com suporte a locking via DynamoDB.
  * **Segurança Granular:** Permite configurar Políticas de Confiança (*Trust Policies*) refinadas avaliando as claims `sub` e `aud` emitidas pelo GitHub OIDC.
  * **Facilidade de Replicação:** Módulo reutilizável e parametrizável para novas contas AWS, regiões ou múltiplos ambientes (*dev*, *staging*, *prod*).
* **Contras:**
  * Desafio de bootstrap inicial (problema do "ovo e da galinha"): o primeiro deploy do módulo OIDC requer privilégios temporários executados por um perfil de engenharia de plataforma.

---

## Resultado da Decisão (Decision Outcome)

**Opção Escolhida:** Opção 3 — Provisionamento de OIDC e IAM Roles via Terraform (Declarativo / IaC).

Esta opção atende integralmente aos requisitos de segurança moderna, auditabilidade e automação declarativa. O GitHub atua como um provedor de identidade confiável, emitindo tokens JSON Web Token (JWT) de curta duração por execução de *workflow*, trocados via AWS Security Token Service (STS) por credenciais efêmeras diretamente na etapa de inicialização dos jobs.

---

## Consequências

### Impactos Positivos
* **Eliminação de Riscos de Credenciais:** Ausência de chaves de acesso de longa duração nos GitHub Secrets.
* **Segregação por Ambiência e Branch:** A Role de Produção só pode ser assumida por solicitações vindas da branch `main`, enquanto a de Desenvolvimento aceita branches de funcionalidade (`feature/*`) ou eventos de Pull Request.
* **Auditoria Aprimorada:** O AWS CloudTrail registra o repositório, workflow, commit SHA, ator e branch de cada operação realizada no EKS ou ECR.

### Desafios e Mitigações
* **Bootstrap Inicial:** O módulo Terraform de OIDC precisa existir na AWS antes que o pipeline de CI/CD possa rodar de forma automatizada.
  * *Mitigação:* Realização do provisionamento inicial do módulo de OIDC localmente por um Cloud Architect com acesso administrativo temporário, persistindo o arquivo de estado no bucket S3 remoto do projeto.

---

## Plano de Implementação

### 1. Código Terraform (HCL) — Módulo OIDC e IAM Roles (`terraform/modules/oidc/main.tf`)

```hcl
# ------------------------------------------------------------------------------
# Provedor OIDC do GitHub Actions na AWS com Busca Dinâmica de Certificados
# ------------------------------------------------------------------------------
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = {
    Environment = var.environment
    Project     = "template-cluster-kubernetes-ci-cd"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# IAM Role para CI/CD com Trust Policy restrita por repositório e branch
# ------------------------------------------------------------------------------
resource "aws_iam_role" "github_actions_ci_cd" {
  name        = "github-actions-eks-ecr-${var.environment}-role"
  description = "Role efemera para execucao do pipeline de CI/CD do GitHub Actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Suporta o formato clássico e o novo formato OIDC com IDs imutáveis (padrão GitHub pós 15/07/2026)
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.allowed_branch}",
              "repo:${var.github_org}*/${var.github_repo}*:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# Política IAM: Permissões de Menor Privilégio para Amazon ECR
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "ecr_policy" {
  name        = "github-actions-ecr-${var.environment}-policy"
  description = "Permissoes de menor privilegio para push e pull de imagens no Amazon ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.ecr_repository_name}"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Política IAM: Permissões de Menor Privilégio para Amazon EKS
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "eks_policy" {
  name        = "github-actions-eks-${var.environment}-policy"
  description = "Permissoes necessarias para atualizar kubeconfig e implantar recursos no EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/${var.eks_cluster_name}"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Associando as Políticas à IAM Role
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "attach_ecr" {
  role       = aws_iam_role.github_actions_ci_cd.name
  policy_arn = aws_iam_policy.ecr_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_eks" {
  role       = aws_iam_role.github_actions_ci_cd.name
  policy_arn = aws_iam_policy.eks_policy.arn
}
```

### 2. Workflow GitHub Actions (YAML) — Autenticação Keyless (`.github/workflows/02-infrastructure-ci-cd.yml`)

```yaml
name: "02 - Infrastructure & App Deployment"

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

# OBRIGATÓRIO: Permissão id-token: write necessária para emissão do token JWT OIDC pelo GitHub
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    name: "Deploy Infrastructure & Workloads"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout do Repositório
        uses: actions/checkout@v4

      - name: Autenticação Keyless na AWS via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-eks-ecr-prod-role
          aws-region: us-east-1
          audience: sts.amazonaws.com

      - name: Validação da Identidade Assumida via STS
        run: |
          echo "🔒 Autenticação OIDC Keyless realizada com sucesso!"
          aws sts get-caller-identity

      - name: Autenticação no Amazon ECR
        run: |
          aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```
