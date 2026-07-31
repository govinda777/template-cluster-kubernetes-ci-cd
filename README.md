# 🚀 Template Cluster Kubernetes CI/CD (Multi-Cloud Platform Accelerator)

Bem-vindo ao **`template-cluster-kubernetes-ci-cd`**, um acelerador de plataforma corporativa projetado para fornecer infraestrutura Kubernetes multi-cloud (AWS, GCP, Azure) pronta para produção, escalável e segura.

Este repositório estabelece um caminho pavimentado (Golden Path) para times de desenvolvimento, abstraindo a complexidade da infraestrutura e habilitando práticas modernas de Platform Engineering.

---

## ✨ Principais Características

- **☁️ Multi-Cloud Nativo**: Suporte para provisionamento no Amazon EKS (AWS), Google Kubernetes Engine (GCP) e Azure Kubernetes Service (AKS), mitigando lock-in de provedor.
- **🏗️ Infraestrutura como Código (IaC)**: Totalmente gerenciado usando **OpenTofu** (fork open-source do Terraform).
- **🔄 GitOps por Padrão**: Sincronização e reconciliação contínua de estado via **ArgoCD** e `ApplicationSets` dinâmicos.
- **🔒 Segurança Zero-Trust**: Sem chaves estáticas. Autenticação via **OIDC (OpenID Connect)** para o GitHub Actions e **Pod Identity Agent / Workload Identity** para as aplicações.
- **🚦 Modern Networking**: Substituição dos tradicionais `Ingress` por **Kubernetes Gateway API** para roteamento de tráfego avançado e desacoplado.
- **📊 Observabilidade Integrada**: Stack completa de monitoramento implantada via ArgoCD com **Prometheus, Grafana e Loki**.
- **🛡️ Qualidade e Conformidade**: Políticas de configuração validadas através do **OPA (Open Policy Agent)** e **Conftest**.

---

## 📚 Documentação Oficial da Plataforma

Nossa documentação técnica é abrangente e dividida por áreas de interesse:

- **[🏛️ Arquitetura de Software (C4 Model) e Design](ARCHITECTURE.md)**: Visão geral topológica e decisões de arquitetura.
- **[📖 Manual Completo da Plataforma (Platform Engineering Handbook)](PLATFORM.md)**: Guia oficial de engenharia, ciclo de vida GitOps, e roteamento de rede.
- **[🚦 Guia de Adoção da Kubernetes Gateway API](docs/gateway-api-adoption-guide.md)**: Regras, exemplos e transição de Ingress para Gateway API.
- **[🔑 Autenticação AWS e Integração com Git](docs/DOCS_AUTENTICACAO_AWS_GIT.md)**: Como o AWS SSO (IAM Identity Center) foi configurado para acesso seguro.
- **[🌐 Autenticação GCP e Workload Identity](docs/DOCS_AUTENTICACAO_GCP_WIF.md)**: Guia de onboarding para provisionar e acessar recursos do Google Cloud via WIF.
- **[🚑 Recuperação e Acesso ao EKS](docs/eks-access-recovery-guide.md)**: Guia técnico de recuperação de acesso utilizando EKS Access Entries.
- **[💥 ADR-004: Procedimento de Destruição e Reconstrução](docs/adr/0004-procedimento-destruicao-reconstrucao.md)**: Processo documentado para testes de "Clean Slate" em Disaster Recovery.

---

## 🚀 Quickstart e Onboarding

A plataforma utiliza um `Makefile` unificado para simplificar todo o processo de autenticação e validação local, além de scripts inteligentes que configuram o ambiente na sua máquina de forma interativa.

### 1. Autenticação na Nuvem Desejada (SSO)

Dependendo de onde você deseja implantar seu ambiente, execute o assistente de configuração (ele instalará dependências ausentes, fará login SSO via browser e persistirá seu perfil localmente em um `.env`):

- **Para AWS:**

    ```bash
    make config aws
    ```

- **Para GCP:**

    ```bash
    make config gcp
    ```

- **Para Azure:**

    ```bash
    make config azure
    ```

*Alternativa: Para rodar um bootstrap global de OIDC/WIF de uma vez, execute `make config all`.*

### 2. Configurar o Kubeconfig Local

Após provisionar um cluster de desenvolvimento (via pipeline), configure o seu contexto `kubectl` local rodando:

```bash
make config kube
```

### 3. Testar o Pipeline Localmente

Você pode emular os estágios exatos do GitHub Actions (Pre-flight checks, Tofu Plan, Validações) no seu terminal antes de fazer um push ou abrir um Pull Request:

```bash
make run pipeline
```

*(Se não houver bucket S3 remoto configurado, este script falhará de forma segura para o backend local do Tofu em sua máquina, restaurando as configurações assim que finalizar).*

---

## 📂 Estrutura do Repositório

```text
.
├── .github/                  # Workflows de CI/CD (GitHub Actions)
├── apps-template/            # Templates (Golden Paths) para onboarding de aplicações
├── crossplane/               # Manifestos de recursos gerenciados (AWS RDS, etc) via Crossplane
├── docs/                     # Guias técnicos, Manuais operacionais e ADRs
├── platform-apps/            # Helm charts e manifestos gerenciados pelo ArgoCD (Observabilidade, etc)
├── scripts/                  # Scripts bash interativos (autenticação, pipelines locais, utilitários)
├── terraform/                # Código de infraestrutura (OpenTofu)
│   ├── bootstrap/            # Configuração global de provedores de identidade (OIDC GitHub)
│   ├── live/                 # Ambientes instanciados (dev/ e prod/)
│   └── modules/              # Módulos reutilizáveis (vpc, eks, gke, etc)
└── tests/                    # Suíte de testes de integração (Terratest em Go)
```

---

## 🤝 Contribuição e Pipelines CI/CD

Todas as contribuições devem passar pelo nosso fluxo rigoroso de CI/CD. Qualquer Pull Request criado engatilhará o arquivo `.github/workflows/ci-cd.yml`, que executará os seguintes passos de forma automatizada:

1. **Code Linting & Formatting**: `tofu fmt`, `yamllint`, etc.
2. **Security Scans e OPA Validations**: Garantia contra recursos obsoletos.
3. **Tofu Plan (Dry-run)**: Validação do plano de execução em `dev` e `prod`.
4. *(Somente na branch principal)* **Tofu Apply**: Implantação progressiva.
5. **Testes E2E (Terratest)**: Verificação efêmera da infraestrutura via scripts Go.

---
> Desenvolvido com foco na experiência do desenvolvedor e padrões de confiabilidade do SRE.
