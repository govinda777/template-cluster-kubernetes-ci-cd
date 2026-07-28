#!/usr/bin/env bash

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="local-platform"

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🧪 Executando Testes BDD / Integração Locais (Pre-push DoD)${NC}"
echo -e "${BLUE}========================================================================${NC}"

# 1. Verificar Pré-requisitos
if ! bash "$(dirname "$0")/check-prerequisites.sh"; then
    exit 1
fi

# 2. Verificar se o cluster Kind local está ativo
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${RED}❌ Erro: O cluster local '$CLUSTER_NAME' não está rodando.${NC}"
    echo -e "${YELLOW}Por favor, inicie-o executando: bash .agents/skills/local-dev-and-testing/scripts/setup-local-env.sh${NC}"
    exit 1
fi

kubectl config use-context "kind-$CLUSTER_NAME"

# 2. Deploy dos manifestos da aplicação (apps-template)
echo "🚀 Aplicando manifestos locais..."
kubectl apply -f apps-template/base/deployment.yaml
kubectl apply -f apps-template/base/service.yaml
kubectl apply -f apps-template/base/http-route.yaml

# Garantir limpeza no final
cleanup() {
    echo "🧹 Limpando manifestos locais..."
    kubectl delete -f apps-template/base/http-route.yaml --ignore-not-found=true
    kubectl delete -f apps-template/base/service.yaml --ignore-not-found=true
    kubectl delete -f apps-template/base/deployment.yaml --ignore-not-found=true
}
trap cleanup EXIT

# 3. Validar se os Pods iniciam e ficam Ready
echo "⏳ Aguardando os Pods do template da aplicação ficarem prontos (app=api-example)..."
kubectl wait --for=condition=ready pod -l app=api-example --timeout=60s

# 4. Validar comportamento da Gateway API / Serviço via Port-forward
echo "🌐 Iniciando encaminhamento de porta temporário para o serviço..."
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

kubectl port-forward svc/api-example-svc "$PORT":80 >/dev/null 2>&1 &
PF_PID=$!

# Função para garantir a morte do processo de port-forward
cleanup_pf() {
    kill "$PF_PID" 2>/dev/null || true
}
trap "cleanup_pf; cleanup" EXIT

# Dar um tempo para o port-forward inicializar
sleep 2

# 5. Executar chamadas HTTP (Verificação de Comportamento BDD)
ENDPOINT="http://127.0.0.1:$PORT"
echo "🔍 Enviando requisição de teste para $ENDPOINT..."

RESPONSE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT")

if [ "$RESPONSE_STATUS" -eq 200 ]; then
    echo -e "${GREEN}✅ Teste BDD Passou! Resposta recebida com sucesso (HTTP 200).${NC}"
    echo -e "${GREEN}A aplicação se comporta corretamente no ambiente Kubernetes local!${NC}"
else
    echo -e "${RED}❌ Teste BDD Falhou! Status HTTP retornado: $RESPONSE_STATUS (Esperado: 200).${NC}"
    exit 1
fi
