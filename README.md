# 🚀 Platform Accelerator: Multi-Cloud Kubernetes & GitOps Platform

[![OpenTofu](https://img.shields.io/badge/IaC-OpenTofu-FF5733?style=flat-square&logo=opentofu)](https://opentofu.org/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30-326CE5?style=flat-square&logo=kubernetes)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-FF512F?style=flat-square&logo=argo)](https://argoproj.github.io/cd/)
[![Gateway API](https://img.shields.io/badge/Networking-Gateway%20API-blue?style=flat-square&logo=kubernetes)](https://gateway-api.sigs.k8s.io/)
[![Security](https://img.shields.io/badge/Security-Zero--Trust-success?style=flat-square)](docs/DOCS_AUTENTICACAO_AWS_GIT.md)

Este repositório é um **Acelerador de Plataforma (Platform Accelerator)** projetado para atuar como o **Caminho Pavimentado (Golden Path)** definitivo para engenharia de plataforma moderna. Ele oferece uma arquitetura robusta, segura, declarativa e altamente escalável para provisionar, gerenciar e monitorar clusters Kubernetes multi-cloud (AWS EKS, GCP GKE, Azure AKS) utilizando práticas modernas de **GitOps**, **Zero-Trust Security** e **Modern Networking**.

Com este acelerador, os times de produto e infraestrutura podem focar na entrega de valor ao negócio, enquanto a plataforma cuida automaticamente da conformidade de rede, governança, identidade de pods, gerenciamento de segredos e observabilidade granular.

---

## 🏛️ Visão Geral da Arquitetura

O projeto adota uma separação rigorosa entre a camada física de infraestrutura, os aplicativos de plataforma (plumbing) e as cargas de trabalho (workloads) das equipes de desenvolvimento.

```text
 ┌───────────────────────┐       ┌───────────────────────┐       ┌───────────────────────┐
 │   Infraestrutura      │ ────► │      Plataforma       │ ────► │       Workloads       │
 │ (IaC modular OpenTofu)│       │ (GitOps Auto-Sinc via)│       │  (Gateway API & Pods  │
 │                       │       │ (ArgoCD AppSets)      │       │     Declarativos)     │
 └───────────────────────┘       └───────────────────────┘       └───────────────────────┘
```

Para uma análise técnica detalhada dos fluxos de tráfego (Inbound), diagramas C4 (Contexto e Contêineres) e decisões arquiteturais de rede, consulte a [Documentação de Arquitetura de Software (ARCHITECTURE.md)](ARCHITECTURE.md).

---

## 💎 Principais Funcionalidades & Diferenciais

### 1. 🏗️ Infraestrutura como Código Moderna (OpenTofu)
- **Código Reutilizável**: Módulos Terraform/OpenTofu flexíveis e desacoplados para provisionar VPCs completas, clusters EKS (AWS), GKE (GCP) e AKS (Azure) em `terraform/modules/`.
- **Separação de Ambientes**: Implementações em ambientes live (`terraform/live/dev` e `terraform/live/prod`) com gerenciamento remoto de estados criptografados e proteção de concorrência com travas no DynamoDB.

### 2. 🔄 Reconciliação GitOps Dinâmica (ArgoCD)
- **Padrão Hub-and-Spoke**: Bootstrap automático de componentes de plataforma utilizando ArgoCD `ApplicationSets`.
- **Matrix / Cluster Generator**: Detecção automatizada de clusters registrados por rótulos (labels). Quando um novo cluster é adicionado, o ArgoCD instala dinamicamente ferramentas vitais (Cilium, AWS Load Balancer Controller, External Secrets Operator, Prometheus) sem intervenção humana.

### 3. 🌐 Rede de Próxima Geração (Kubernetes Gateway API)
- **Desacoplamento de Papéis**: Substituição total de Ingress tradicionais por recursos baseados em papéis de usuário (Platform Team gerencia o `Gateway` físico e App Devs definem o `HTTPRoute`).
- **Integração Nativa**: Utiliza o AWS Load Balancer Controller para mapear `Gateway` em AWS ALBs de alta performance de forma automática.
- Para saber como adotar e configurar, acesse o [Guia de Adoção da Gateway API (docs/gateway-api-adoption-guide.md)](docs/gateway-api-adoption-guide.md).

### 4. 🔒 Segurança Zero-Trust & Sem Senhas (OIDC & Pod Identity)
- **Autenticação Keyless em CI/CD**: Pipelines do GitHub Actions conectam-se de forma segura à nuvem utilizando autenticação baseada em certificados OIDC (OpenID Connect), eliminando chaves estáticas (`AWS_ACCESS_KEY_ID`).
- **EKS Pod Identity Agent**: Aplicações em execução assumem roles IAM dinamicamente através do novo agente integrado, abolindo as anotações do legado IRSA.
- **External Secrets Operator (ESO)**: Sincronização segura de segredos efêmeros integrados diretamente ao AWS Secrets Manager.
- Compreenda as medidas criptográficas e de auditoria no [Manual de Autenticação Segura (docs/DOCS_AUTENTICACAO_AWS_GIT.md)](docs/DOCS_AUTENTICACAO_AWS_GIT.md).

### 5. 📊 Observabilidade de Ponta a Ponta
- **Pilha de Telemetria**: Integração completa do `kube-prometheus-stack` (Prometheus + Grafana + Loki) gerenciado declarativamente.
- **Scraping Global**: Configurado com seletores globais para coletar e correlacionar métricas e logs de qualquer namespace de forma instantânea.
- Consulte detalhes operacionais no [Manual de Observabilidade da Plataforma (docs/DOCS_OBSERVABILIDADE.md)](docs/DOCS_OBSERVABILIDADE.md).

### 6. ⚖️ Governança e Qualidade Integradas (OPA / Conftest)
- **Políticas como Código**: Validação estrita via Conftest utilizando regras escritas em Rego (`tests/policies/`).
- **Bloqueio de Ingress Legados**: O sistema de validação rejeita sumariamente manifestos que configurem recursos baseados na especificação antiga `Ingress`, obrigando a adoção da nova Gateway API.

---

## 📂 Estrutura do Repositório

```text
.
├── .github/workflows/       # Pipelines de CI/CD (GitHub Actions) para Dev/Prod
├── apps-template/           # Modelos de manifestos de aplicações (Kustomize base/overlays)
├── crossplane/              # Declarações multi-cloud para recursos gerenciados (Ex: RDS PostgreSQL)
├── docs/                    # Guias operacionais técnicos detalhados e ADRs
│   ├── adr/                 # Registro de Decisões de Arquitetura (ADRs)
│   ├── gateway-api-...      # Guia de transição e adoção de Gateway API
│   ├── DOCS_AUTENTICACAO... # Detalhamento técnico da segurança Git + AWS
│   └── DOCS_OBSERVABILIDADE # Guia de arquitetura de métricas, alertas e logs
├── platform-apps/           # Helm Charts e ApplicationSets gerenciados pelo ArgoCD (GitOps)
├── scripts/                 # Scripts auxiliares para validação, autenticação local e pipeline
├── terraform/               # Infraestrutura como Código (IaC) modular e declarativa
│   ├── bootstrap/           # Provisionamento do provedor OIDC e Secrets para o GitHub
│   ├── live/                # Ambientes físicos separados (dev, prod)
│   └── modules/             # Módulos reusáveis (VPC, EKS, GKE, AKS, Pod Identity)
├── tests/                   # Testes de integração (Terratest em Go) e Políticas Rego (OPA)
├── ARCHITECTURE.md          # Documentação detalhada da arquitetura corporativa
├── PLATFORM.md              # Manual Operacional da Plataforma (Platform Engineering Handbook)
└── README.md                # Este guia de introdução
```

---

## 🚀 Quickstart: Guia de Inicialização Rápida

### Pré-requisitos Locais
Para interagir com o acelerador de forma ideal, certifique-se de instalar os seguintes utilitários locais:
- AWS CLI, GitHub CLI (`gh`), OpenTofu (`tofu`) ou Terraform, `jq` e Git.
- *Nota: O script de inicialização automática detecta o seu sistema operacional e pode auxiliar na instalação caso estes componentes estejam ausentes.*

---

### Passo 1: Autenticação Segura via AWS SSO (Recomendado)
A plataforma desativa o uso de chaves permanentes de longa duração para garantir máxima segurança local. Para se autenticar:

1. Execute o assistente de onboarding local fornecido pelo root `Makefile`:
   ```bash
   make config aws
   ```
2. Forneça a **AWS SSO Start URL** e a **Região** quando solicitado. O utilitário abrirá uma sessão no seu navegador para validar o token dinâmico.
3. O script criará automaticamente o arquivo local `.aws_profile_env` contendo as variáveis que o `Makefile` exporta silenciosamente (`AWS_PROFILE` e `AWS_REGION`).

*Se estiver utilizando Azure ou GCP:*
```bash
make config gcp      # Autenticação integrada no Google Cloud
make config azure    # Autenticação integrada no Microsoft Azure
```

---

### Passo 2: Validar a Configuração Local
Para verificar se as tabelas DynamoDB, Buckets S3 de Backend, perfis de rede e as versões do Kubernetes desejadas para o EKS estão saudáveis e acessíveis antes de iniciar o deployment, execute:
```bash
bash scripts/validate-config.sh
```

---

### Passo 3: Executar a Pipeline Inteira Localmente (Simulação)
O projeto inclui um executor local avançado que simula com precisão as etapas de integração contínua (CI/CD) que rodam no GitHub Actions. Ele valida politicas OPA, estados do OpenTofu e planos de deployment sem a necessidade de enviar commits ao Git:

```bash
make run pipeline
```
*(ou utilize o comando equivalente `make run-pipeline`)*

---

## 📖 Índice de Documentação e Manuais Técnicos

Explore nossos guias complementares para dominar a operação e governança do ecossistema:

1. **[Manual Completo da Plataforma (PLATFORM.md)](PLATFORM.md)**: O manual de Platform Engineering cobrindo estratégias de alta disponibilidade multi-cloud (ativo-ativo vs ativo-passivo), HPA/Karpenter para auto-scaling, e procedimentos de disaster recovery.
2. **[Arquitetura e Redes (ARCHITECTURE.md)](ARCHITECTURE.md)**: Diagramas técnicos em nível C4, fluxos de tráfego detalhados e pilares de design de infraestrutura.
3. **[Guia de Adoção de Gateway API (docs/gateway-api-adoption-guide.md)](docs/gateway-api-adoption-guide.md)**: Manual técnico detalhado explicando a quebra de paradigmas do Ingress tradicional e como declarar e operar `HTTPRoute` com segurança.
4. **[Segurança e Conectividade AWS (docs/DOCS_AUTENTICACAO_AWS_GIT.md)](docs/DOCS_AUTENTICACAO_AWS_GIT.md)**: Funcionamento interno do fluxo OIDC, assinatura de requisições SigV4, rotação automatizada de impressões digitais SSL e auditoria via AWS CloudTrail.
5. **[Plataforma de Observabilidade (docs/DOCS_OBSERVABILIDADE.md)](docs/DOCS_OBSERVABILIDADE.md)**: Detalhamento técnico da arquitetura de scraping do Prometheus, visualizações do Grafana e agregação distribuída de logs com Loki.
6. **Decisões Arquiteturais Registradas (ADRs)**:
   - **[ADR-001: Substituição do Ingress tradicional pela Kubernetes Gateway API](docs/adr/0001-substituicao-ingress-gateway-api.md)**
   - **[ADR-002: Adoção do GitOps declarativo via ArgoCD e ApplicationSets](docs/adr/0002-adocao-gitops-argocd.md)**
   - **[ADR-003: Autenticação Keyless de CI/CD via AWS OIDC Federation](docs/adr/0003-padrao-autenticacao-keyless-github-aws.md)**

---

## 📄 Licença
Este projeto é licenciado sob os termos descritos no arquivo [LICENSE](LICENSE).
