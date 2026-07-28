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
for cmd in docker kind kubectl kustomize; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}❌ Erro: O comando '$cmd' é requerido mas não está instalado.${NC}"
        exit 1
    fi
    echo "   [OK] $cmd encontrado."
done

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
kubectl apply -f https://github.com/envoyproxy/gateway-helm/releases/download/v1.1.0/install.yaml

# 6. Instalar o ArgoCD
echo "📦 Instalando ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 7. Aguardar pods ficarem prontos
echo "⏳ Aguardando a inicialização básica do ArgoCD e do Gateway Controller..."
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=180s || echo -e "${YELLOW}⚠️  Aviso: Timeout esperando o servidor ArgoCD. Continuando...${NC}"

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}🎉 Ambiente Local Prontinho!${NC}"
echo -e "${GREEN}========================================================================${NC}"
