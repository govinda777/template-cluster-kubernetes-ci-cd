#!/usr/bin/env bash

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🛠️  Instanciando Ambiente de Desenvolvimento Local (ADR 0006)${NC}"
echo -e "${BLUE}========================================================================${NC}"

# 1. Verificar Pré-requisitos
echo "🔍 Verificando pré-requisitos..."
if ! bash "$(dirname "$0")/check-prerequisites.sh"; then
    exit 1
fi

# 2. Criar Configuração do Kind
KIND_CONFIG_PATH="/tmp/kind-local-config.yaml"
echo "⚙️  Gerando configuração do Kind..."
cat <<EOF > "$KIND_CONFIG_PATH"
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

# 3. Criar o Cluster
CLUSTER_NAME="local-platform"
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}⚠️  Aviso: O cluster Kind '$CLUSTER_NAME' já existe. Pulando criação...${NC}"
else
    echo "🚀 Criando cluster Kind '$CLUSTER_NAME'..."
    kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG_PATH"
fi

# Ajustar contexto do Kubectl
kubectl config use-context "kind-$CLUSTER_NAME"

# 4. Instalar CRDs da Gateway API
echo "🌐 Instalando CRDs da Gateway API (v1.1.0)..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# 5. Instalar o Envoy Gateway Controller
echo "🛡️  Instalando Envoy Gateway Controller..."
kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.1.0/install.yaml

# 6. Instalar o ArgoCD
echo "📦 Instalando ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 7. Aguardar pods ficarem prontos
echo "⏳ Aguardando a inicialização básica do ArgoCD e do Gateway Controller..."
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=180s || echo -e "${YELLOW}⚠️  Aviso: Timeout esperando o servidor ArgoCD. Continuando...${NC}"

# 8. Instalar Banco de Dados PostgreSQL (Local Dev)
echo "💾 Configurando Banco de Dados PostgreSQL para o n8n..."
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f platform-apps/infrastructure-apps/postgres/secret.yaml
kubectl apply -f platform-apps/infrastructure-apps/postgres/local-deployment.yaml

# 9. Configurar Gateway local
echo "🌐 Configurando Gateway API local..."
kubectl apply -f platform-apps/infrastructure-apps/n8n/local-gateway.yaml

# 10. Instalar n8n
echo "🤖 Instalando n8n..."
kubectl create namespace platform-tools --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f platform-apps/infrastructure-apps/n8n/secret.yaml
kubectl apply -f platform-apps/infrastructure-apps/n8n/deployment.yaml
kubectl apply -f platform-apps/infrastructure-apps/n8n/service.yaml
kubectl apply -f platform-apps/infrastructure-apps/n8n/http-route.yaml

# 11. Aguardar Banco de Dados e n8n ficarem prontos
echo "⏳ Aguardando Banco de Dados PostgreSQL..."
kubectl wait --namespace database \
  --for=condition=ready pod \
  -l app=postgresql-dev \
  --timeout=120s

echo "⏳ Aguardando n8n ficar pronto..."
kubectl wait --namespace platform-tools \
  --for=condition=ready pod \
  -l app=n8n \
  --timeout=120s

# 12. Iniciar Port-Forward para o n8n em background
echo "🔌 Iniciando port-forward para o n8n na porta 5678..."
# Matar port-forwards anteriores na mesma porta se existirem
pkill -f "port-forward.*n8n-service" || true
nohup kubectl port-forward --namespace platform-tools svc/n8n-service 5678:5678 >/dev/null 2>&1 &

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}🎉 Ambiente Local Prontinho!${NC}"
echo -e "${GREEN}🚀 Acesse o n8n em: http://localhost:5678${NC}"
echo -e "${GREEN}========================================================================${NC}"

