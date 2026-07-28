# ADR 0006: Procedimento de Criação e Destruição de Ambiente Local Sem Dependência de Nuvem

## Status
Aprovado

## Contexto
Atualmente, a plataforma suporta provisionamento de clusters multi-cloud na AWS (EKS) e GCP (GKE). No entanto, para fins de desenvolvimento rápido, redução de custos na nuvem e testes offline, os desenvolvedores precisam ser capazes de instanciar e testar a plataforma completa (incluindo Gateway API, ArgoCD e aplicações de infraestrutura) diretamente em suas máquinas locais, de forma isolada e sem dependências de provedores de nuvem pública.

---

## Decisão

Adotamos a especificação de um fluxo nativo para desenvolvimento local baseado em **Kind (Kubernetes in Docker)** ou **Minikube** como provedores do cluster Kubernetes local, e a emulação/simplificação de recursos de rede locais (como LoadBalancer) usando o **MetalLB** ou encaminhamento de portas (`port-forward`), permitindo a implantação de todo o ecossistema GitOps localmente.

---

## Procedimento de Construção (Local Setup)

### Pré-requisitos Locais
Você precisará das seguintes ferramentas instaladas:
* [Docker Desktop](https://www.docker.com/) ou Colima
* [Kind](https://kind.sigs.k8s.io/) ou [Minikube](https://minikube.sigs.k8s.io/)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/)
* [Kustomize](https://kustomize.io/)

---

### Passo 1: Criar o Cluster Kubernetes Local

#### Opção A: Usando Kind (Recomendado)
Crie um arquivo de configuração do Kind para expor as portas HTTP (80) e HTTPS (443) da sua máquina para o cluster:

```bash
cat <<EOF > kind-local-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
    protocol: TCP
  - containerPort: 30443
    hostPort: 443
    protocol: TCP
EOF

# Criar o cluster
kind create cluster --name local-platform --config kind-local-config.yaml
```

#### Opção B: Usando Minikube
```bash
minikube start --driver=docker --addons=ingress,dashboard
```

---

### Passo 2: Instalar CRDs da Gateway API (Requisito da Plataforma)
Como a plataforma adota a **Gateway API** em substituição ao Ingress clássico (conforme ADR 0001), instale os CRDs oficiais no cluster local:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
```

---

### Passo 3: Provisionar o Gateway Controller Local (ex: Envoy Gateway ou Cilium)
Para que as rotas (`HTTPRoute`) funcionem localmente, instale um controlador compatível. Exemplo prático usando Envoy Gateway:

```bash
kubectl apply -f https://github.com/envoyproxy/gateway-helm/releases/download/v1.1.0/install.yaml
```

---

### Passo 4: Aplicar as Aplicações e ArgoCD Localmente

1. **Instalar o ArgoCD localmente:**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. **Aplicar a estrutura GitOps local via Kustomize:**
   Navegue até a pasta de aplicações e instale os recursos locais (ajustando segredos e mockando variáveis de nuvem):
   ```bash
   # Exemplo de deploy manual de aplicações de infraestrutura locais
   kubectl apply -k platform-apps/infrastructure-apps/
   ```

---

## Procedimento de Destruição (Local Cleanup)

Para limpar completamente o ambiente local de desenvolvimento, liberar espaço em disco e remover quaisquer dados de testes, execute:

### Destruindo o Cluster Kind
```bash
# Apaga o cluster e remove todos os containers e volumes Docker associados
kind delete cluster --name local-platform
rm -f kind-local-config.yaml
```

### Destruindo o Cluster Minikube
```bash
minikube delete
```

### Limpeza de Resíduos no Docker
Caso queira garantir que todas as imagens de cache e volumes órfãos criados nos testes locais sejam limpos:
```bash
docker system prune -a --volumes --force
```

---

## Consequências

* **Pontos Positivos:**
  * **Custo Zero:** Desenvolvimento e validação sem custos de AWS EKS ou GCP GKE.
  * **Velocidade:** Ciclo de feedback extremamente rápido para alteração de manifestos.
  * **Segurança:** Sem risco de vazamento de credenciais locais de nuvem ou alteração de recursos de produção.
* **Pontos de Atenção:**
  * **Mock de Serviços de Nuvem:** Serviços como banco de dados RDS ou buckets S3 do backend de storage devem ser rodados em containers Docker locais (ex: Postgres local em vez de AWS RDS, MinIO em vez de AWS S3) ou mockados no Kubernetes local.
