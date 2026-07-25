# ADR-002: Adoção de GitOps via ArgoCD em vez do Helm Provider no Terraform

* **Status:** Aceito
* **Data:** 2025-11-07
* **Decisores:** Engenheiro Principal de Plataforma & SRE Architect

---

### 1. Contexto e Problema
O provisionamento de componentes e aplicações de plataforma (como CNI, Controllers de Load Balancer, Observabilidade e Operadores) pode ser feito de duas maneiras principais:
- **Via Terraform (Helm Provider)**: Declarar recursos `helm_release` no mesmo código que gerencia a infraestrutura física (VPC, clusters EKS).
- **Via GitOps (ArgoCD)**: Separar o provisionamento da infraestrutura do gerenciamento das aplicações Kubernetes, utilizando um controlador de entrega contínua que sincroniza o cluster a partir do Git.

Usar o Helm Provider no Terraform gera forte acoplamento do estado da infraestrutura com o runtime do Kubernetes. Mudanças de rede ou falhas na API do Kubernetes durante o execution plan do Terraform podem travar ou corromper o estado do Terraform, impossibilitando a alteração de recursos de infraestrutura física. Além disso, o Terraform não realiza reconciliação contínua e ativa de drift em runtime.

### 2. Drivers da Decisão (Critérios de Avaliação)
* **Estabilidade e Isolamento de Estado**: Isolar o estado do Terraform/OpenTofu de falhas e dependências em runtime do Kubernetes.
* **Reconciliação Ativa (Self-Healing)**: Detectar e reverter alterações manuais (drifts) no cluster instantaneamente.
* **Velocidade de Onboarding**: Simplificar o ciclo de vida de deploy de microsserviços sem exigir conhecimentos em Terraform por parte dos desenvolvedores.

### 3. Opções Consideradas
* **Opção 1: Uso de Helm Provider no Terraform**: Gerenciar todo o ecossistema de aplicações de plataforma via recursos `helm_release` acoplados no Terraform.
* **Opção 2: Separação de Responsabilidades via GitOps (ArgoCD)**: O Terraform gerencia apenas a infraestrutura física básica (VPC, Clusters, IAM). Uma vez criado o cluster, o ArgoCD assume todo o ciclo de vida dos manifestos de plataforma e aplicação de forma autônoma.

### 4. Decisão Escolhida e Justificação
Escolhemos a **Opção 2 (Separação de Responsabilidades via GitOps com ArgoCD)**.

Essa escolha isola o ciclo de vida da infraestrutura de rede e computação (gerido via OpenTofu/Terraform) do ciclo de vida das aplicações Kubernetes (gerido via ArgoCD). Isso evita travamentos de estado no Terraform e garante que o cluster permaneça em conformidade contínua com as definições do Git, revertendo automaticamente drifts no Kubernetes (Self-Healing).

---

### 5. Prós e Contras das Opções

#### Opção 1: Helm Provider no Terraform
* 🟢 **Bom:** Single point of execution; provisiona tudo em um único comando `tofu apply`.
* 🔴 **Mau:** Alto risco de corrupção do estado do Terraform; sem reconciliação ativa de drifts; acoplamento excessivo de responsabilidades.

#### Opção 2: GitOps com ArgoCD
* 🟢 **Bom:** Separação estrita de responsabilidades; reconciliação contínua e ativa; visibilidade excelente de recursos via UI do ArgoCD; independência total para os times de desenvolvimento.
* 🔴 **Mau:** Requer um passo inicial de bootstrapping para instalar o ArgoCD no cluster.

---

### 6. Consequências e Impacto
* **Positivas:**
  * Estabilidade e confiabilidade extremas no gerenciamento de estado do OpenTofu.
  * Facilidade de recuperação de desastres (basta aplicar o root ApplicationSet para reconstruir todo o ecossistema do cluster).
* **Negativas / Riscos:**
  * Curva de aprendizado inicial para gerenciar segredos através de operadores do tipo External Secrets em vez de variáveis do Terraform.
* **Ações de Mitigação:**
  * Automatização do bootstrapping do ArgoCD utilizando o padrão `ApplicationSet` no repositório de plataforma (`platform-apps/bootstrap/root-application-set.yaml`).
