# ADR 0005: Utilização da Stack Prometheus, Grafana, Thanos e Kube-State-Metrics para Observabilidade, Resiliência e Dashboards Corporativos

* 
**Status:** Aceito (Accepted) 


* **Data:** 2026-07-25
* 
**Contexto Técnico:** Plataforma base em Kubernetes multi-cluster gerenciada via GitOps/ArgoCD.



---

## 1. Contexto e Problema

O projeto modelo [`template-cluster-kubernetes-ci-cd`](https://www.google.com/search?q=%5Bhttps://github.com/govinda777/template-cluster-kubernetes-ci-cd%5D(https://github.com/govinda777/template-cluster-kubernetes-ci-cd)) foi projetado para provisionar e gerenciar clusters Kubernetes escaláveis e multi-regionais utilizando IaC (OpenTofu) e GitOps (ArgoCD).

Para garantir a confiabilidade operational da plataforma e o acompanhamento de acordos de nível de serviço (SLAs/SLOs), é imperativo padronizar a instalação dos componentes vitais da pilha de observabilidade, monitoramento de *uptime* e painéis analíticos (*dashboards*).

A arquitetura precisa atender aos seguintes requisitos:

1. 
**Coleta de Métricas em Tempo Real e Baixa Latência:** Métricas nativas de nós, pods, control plane e ingress do Kubernetes.


2. 
**Armazenamento de Longo Prazo e Visão Multi-Cluster:** Retenção durável de métricas sem sobrecarregar a `etcd` ou o armazenamento local de réplicas isoladas do Prometheus.


3. 
**Sintetização de Saúde (Uptime Robotic & Synthetic Probing):** Monitoramento contínuo da integridade dos *endpoints* das aplicações e APIs expostas.


4. 
**Visualização Centralizada e Gerenciamento como Código:** Dashboards padronizados declarativamente via GitOps.



---

## 2. Decisão

Decidimos adotar a **stack Prometheus (via Prometheus Operator / Kube-Prometheus-Stack) integrada ao Thanos, Kube-State-Metrics, Grafana e Blackbox Exporter**, orquestrados via **ArgoCD e Helm/Kustomization** no diretório `platform-apps/infrastructure-apps/`.

### Visão Geral do Fluxo de Observabilidade

```
┌──────────────────────────────────────────────────────────────────┐
│                      Cluster Kubernetes (EKS)                    │
│                                                                  │
│  ┌───────────────────────┐         ┌──────────────────────────┐  │
│  │  Kube-State-Metrics   │         │  Prometheus Blackbox Exp │  │
│  │ (Métricas do Cluster) │         │ (Uptime/Synthetic Check) │  │
│  └───────────┬───────────┘         └────────────┬─────────────┘  │
│              │                                  │                │
│              ▼                                  ▼                │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                   Prometheus Agent / Operator              │  │
│  └──────────────────────────────┬─────────────────────────────┘  │
│                                 │ (Thanos Sidecar / Compactor)   │
└─────────────────────────────────┼────────────────────────────────┘
                                  │
                                  ▼
             ┌────────────────────────────────────────┐
             │       AWS S3 (Métricas Históricas)     │
             └────────────────────┬───────────────────┘
                                  │
                                  ▼
             ┌────────────────────────────────────────┐
             │   Grafana (Dashboards Centralizados)   │
             └────────────────────────────────────────┘

```

---

## 3. Componentes da Solução e Justificativas

| Componente | Papel Arquitetural | Benefício Principal |
| --- | --- | --- |
| **Prometheus Operator** | Gerenciamento declarativo da infraestrutura de monitoramento (*ServiceMonitors*, *PodMonitors*). | Permite que os desenvolvedores definam scraping de métricas via YAML diretamente nas aplicações.

 |
| **Kube-State-Metrics** | Geração de métricas de estado do cluster (Deployment status, Node readiness, Pod restarts). | Mapeia o estado de saúde do Kubernetes em tempo real.

 |
| **Thanos** | Armazenamento de longo prazo e agregação de métricas multi-cluster. | Envia blocos de métricas compactados para bucket AWS S3 gerenciado via OpenTofu/Crossplane, reduzindo custos de retenção.

 |
| **Prometheus Blackbox Exporter** | Testes sintéticos (*Uptime Robotic*) via HTTP/HTTPS, ICMP, TCP e DNS. | Valida a disponibilidade externa real dos ingressos configurados no `HTTPRoute` (Gateway API).

 |
| **Grafana** | Visualização de métricas e alertas integrados. | Configurado declarativamente (*Dashboards as Code*) via ConfigMaps e provisionado pelo ArgoCD.

 |

---

## 4. Integração na Estrutura do Repositório

A implementação integrará a estrutura de diretórios existente no repositório:

```text
template-cluster-kubernetes-ci-cd/
├── platform-apps/
│   ├── bootstrap/
│   │   ├── root-application-set.yaml
│   │   └── kustomization.yaml
│   └── infrastructure-apps/
│       ├── aws-load-balancer-controller/
│       ├── cilium/
│       ├── external-secrets/
│       ├── argocd/
│       ├── kube-prometheus-stack/      # <--- NOVO: Prometheus, Kube-State-Metrics, Grafana
│       ├── thanos/                     # <--- NOVO: Thanos Sidecar / Query / Store
│       └── blackbox-exporter/          # <--- NOVO: Uptime e Probing Sintético

```

---

## 5. Implementação Declarativa (Exemplos de Manifestos)

### 5.1. Bootstrapping via ApplicationSet do ArgoCD

Adiciona o módulo de observabilidade ao gerador dinâmico do ArgoCD (`platform-apps/bootstrap/root-application-set.yaml`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-observability
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - app: kube-prometheus-stack
            path: platform-apps/infrastructure-apps/kube-prometheus-stack
          - app: blackbox-exporter
            path: platform-apps/infrastructure-apps/blackbox-exporter
  template:
    metadata:
      name: '{{app}}'
    spec:
      project: default
      source:
        repoURL: 'https://github.com/govinda777/template-cluster-kubernetes-ci-cd.git'
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: monitoring
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true

```

### 5.2. Validação de Uptime Sintético (Probe para Gateway API)

Manifesto para validação contínua dos rotas do `HTTPRoute` (`platform-apps/infrastructure-apps/blackbox-exporter/probe.yaml`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: http-app-uptime-check
  namespace: monitoring
spec:
  interval: 30s
  module: http_2xx
  prober:
    url: prometheus-blackbox-exporter.monitoring.svc.cluster.local:9115
  targets:
    staticConfig:
      targets:
        - https://api.dev.sua-empresa.com/healthz

```

---

## 6. Consequências e Avaliação

### Positivas

* 
**Padronização GitOps Total:** A infraestrutura de monitoramento segue o mesmo ciclo de vida e versionamento por Pull Requests e validação por OpenTofu/Conftest.


* 
**Baixo Consumo de Recursos Local:** O envio contínuo para S3 via Thanos permite manter retenção local curta no Prometheus (ex: 2 a 6 horas), otimizando o uso do volume EBS do cluster.


* 
**Coerência de Segurança:** Permissões do Thanos para gravar no S3 utilizarão estritamente o **AWS EKS Pod Identity** (`pods.eks.amazonaws.com`), garantindo a conformidade com as regras globais do repositório.



### Negativas / Riscos

* **Custo Adicional de Armazenamento:** Leve aumento de custos na AWS referente a requisições PUT/GET e armazenamento de *blobs* de métricas no bucket S3.
* 
**Complexidade de Configuração:** Requer a criação de papéis IAM no módulo Terraform (`terraform/modules/pod-identity/`) dedicados ao Thanos.