# 🌐 Multi-Cloud Kubernetes & CI/CD Template

[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-%23FFDA1A.svg?style=flat&logo=opentofu&logoColor=black)](https://opentofu.org)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-%23EF7B4D.svg?style=flat&logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![Cilium](https://img.shields.io/badge/Cilium-%23F7F9FB.svg?style=flat&logo=cilium&logoColor=black)](https://cilium.io)
[![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=flat&logo=amazon-aws&logoColor=white)](https://aws.amazon.com)
[![GCP](https://img.shields.io/badge/GCP-%234285F4.svg?style=flat&logo=google-cloud&logoColor=white)](https://cloud.google.com)

Este repositório é um **Acelerador de Plataforma (Platform Accelerator)** pronto para produção, multi-cloud (AWS, GCP, Azure) e totalmente declarativo. Ele viabiliza o provisionamento seguro de clusters Kubernetes, automatiza pipelines de CI/CD e estabelece um caminho pavimentado (**Golden Path**) para que times de desenvolvimento façam o deploy de workloads de forma segura, escalável e autônoma.

---

## 🎯 O que o projeto faz?

Este projeto resolve as principais dores de infraestrutura moderna e Platform Engineering, abstraindo complexidades de nuvem e automatizando o ciclo de vida completo de aplicações através de:

1. **Infraestrutura como Código (IaC) Modular**: Provisionamento automatizado de redes (VPCs) e clusters Kubernetes (AWS EKS, GCP GKE, Azure AKS) usando **OpenTofu/Terraform**.
2. **GitOps Nativo com ArgoCD**: Sincronização automática e detecção de desvios (*drift detection*) usando `ApplicationSets` dinâmicos baseados em labels de clusters.
3. **Rede Moderna e Desacoplada**: Implementação de roteamento inteligente de tráfego usando a **Kubernetes Gateway API** (substituindo Ingress legados por HTTPRoutes gerenciados por papéis).
4. **Segurança Zero-Trust e Keyless**:
   - Integração das pipelines do GitHub Actions por meio de **OIDC (OpenID Connect)** eliminando senhas e chaves estáticas de CI/CD.
   - Associação de privilégios a Pods de forma dinâmica via **EKS Pod Identity** (AWS) e **Workload Identity** (GCP/Azure).
5. **Gestão Segura de Segredos**: Sincronização dinâmica de segredos no Kubernetes a partir de gerenciadores de nuvem (como AWS Secrets Manager) usando o **External Secrets Operator (ESO)**.
6. **Políticas como Código e Governança**: Validação contínua de segurança e arquitetura dos manifestos Kubernetes com **OPA (Open Policy Agent) / Conftest**.
7. **Ambiente Local Autossuficiente (ADR 0006)**: Provisionamento local com um único comando de um cluster **Kind (Kubernetes in Docker)** com Envoy Gateway, ArgoCD e validação contínua automatizada por Git Hooks (`pre-commit` para testes unitários/lint e `pre-push` para testes BDD).

---

## 🗺️ Mapa de Documentação Técnica

Toda a arquitetura e guias operacionais estão estruturados detalhadamente no repositório. Use os links abaixo para explorar as especificações técnicas:

### 🏛️ Arquitetura de Software e Decisões
*   **[ARCHITECTURE.md](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/ARCHITECTURE.md)**: Visão geral da arquitetura, princípios de design, fluxos de tráfego inbound e diagramas nos níveis C4 (Contexto, Containers e Roteamento).
*   **Decisões Arquiteturais ([ADRs](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/adr))**:
    *   [ADR 0001: Substituição de Ingress por Kubernetes Gateway API](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/adr/0001-substituicao-ingress-gateway-api.md)
    *   [ADR 0002: Adoção de GitOps com ArgoCD e ApplicationSets](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/adr/0002-adocao-gitops-argocd.md)
    *   [ADR 0003: Padrão de Autenticação Keyless entre GitHub e AWS](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/adr/0003-padrao-autenticacao-keyless-github-aws%20copy.md)
    *   [ADR 0004: Procedimento de Destruição e Reconstrução Segura](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/adr/0004-procedimento-destruicao-reconstrucao.md)
    *   [ADR 0005: Observabilidade e Monitoramento Centralizado](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/adr/0005-observability.md)
    *   [ADR 0005-B: Automação Unificada de Onboarding Multicloud](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/adr/0005-automacao-unificada-onboarding-multicloud.md)
    *   [ADR 0006: Ambiente de Desenvolvimento e Testes Local](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/adr/0006-ambiente-desenvolvimento-local.md)

### 📖 Manuais e Guias Operacionais
*   **[PLATFORM.md](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/PLATFORM.md)**: Manual do Engenheiro de Plataforma (Platform Engineering Handbook). Detalha a governança, estratégias Multi-Cloud (Ativo-Ativo e Warm Standby), integração de identidades (EKS Pod Identity) e monitoramento.
*   **[Gateway API Adoption Guide](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/gateway-api-adoption-guide.md)**: Manual de adoção prática da Gateway API, contendo exemplos reais de `HTTPRoute`, políticas de TLS e troubleshooting de tráfego.
*   **[Quick Start Local (ADR 0006)](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/QUICK_START_LOCAL.md)**: Passo a passo simplificado para subir o ambiente local de testes e CI/CD simulado utilizando Docker e Kind.
*   **[Guia de Autenticação AWS SSO](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/DOCS_AUTENTICACAO_AWS_GIT.md)**: Detalhamento sobre o fluxo sem chaves e autenticação via IAM Identity Center.
*   **[Guia de Autenticação GCP Workload Identity](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/DOCS_AUTENTICACAO_GCP_WIF.md)**: Instruções sobre federação de identidade e autenticação no GCP sem chaves.
*   **[Guia de Observabilidade](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/DOCS_OBSERVABILIDADE.md)**: Documentação sobre Prometheus, Grafana, Loki e métricas agregadas da plataforma.
*   **[EKS Access Recovery Guide](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/docs/eks-access-recovery-guide.md)**: Procedimento operacional padrão (SOP) para recuperação e mitigação de perda de acesso administrativo no AWS EKS.

---

## 🛠️ Como Iniciar

A plataforma conta com uma camada de automação unificada através de um [Makefile](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/Makefile) e scripts utilitários.

### 1. Desenvolvimento e Validação Local (Sem Nuvem)
Se você deseja experimentar a plataforma localmente no Docker usando Kind:
```bash
# 1. Instale os git hooks locais (DoD automatizado)
bash .agents/skills/local-dev-and-testing/scripts/install-hooks.sh

# 2. Inicialize o cluster local com ArgoCD e Gateway API
bash .agents/skills/local-dev-and-testing/scripts/setup-local-env.sh

# 3. Rode os testes locais simulando pipelines (Unitários/Rego e BDD)
bash .agents/skills/local-dev-and-testing/scripts/run-unit-tests.sh
bash .agents/skills/local-dev-and-testing/scripts/run-bdd-tests.sh
```

### 2. Onboarding na Nuvem (AWS & GCP)
Para configurar e se autenticar de forma automática nos provedores de nuvem utilizando melhores práticas (AWS SSO, OIDC, gcloud CLI):
```bash
# Configurar e autenticar na AWS
make config aws

# Configurar e autenticar no GCP
make config gcp

# Executar o setup completo de OIDC federado multi-cloud
make config all
```

---

## 📁 Estrutura de Pastas

*   `terraform/`: Código de infraestrutura IaC (OpenTofu) contendo módulos reutilizáveis e ambientes `live/`.
*   `crossplane/`: Configurações declarativas para provisionar recursos de nuvem gerenciados de dentro do Kubernetes.
*   `platform-apps/`: Manifestos e Helm charts globais instalados no cluster (ArgoCD, Cilium, Gateway Controllers, ESO).
*   `apps-template/`: Templates e exemplos de aplicação/workload de microsserviços integrados com a Gateway API.
*   `scripts/`: Ferramentas auxiliares de onboarding, login, validação e gerenciamento.
*   `docs/`: Documentações técnicas adicionais e Registros de Decisão de Arquitetura (ADRs).
*   `tests/`: Scripts e definições de testes BDD e unitários locais.
