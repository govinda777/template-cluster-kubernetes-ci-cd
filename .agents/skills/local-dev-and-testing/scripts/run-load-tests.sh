#!/usr/bin/env bash

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="local-platform"
NAMESPACE="platform-tools"
SERVICE_NAME="n8n-service"
PORT="5678"

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🧪 Executando Testes BDD de Carga (ApacheBench)${NC}"
echo -e "${BLUE}========================================================================${NC}"

# 1. Verificar se o cluster Kind local está ativo
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${RED}❌ Erro: O cluster local '$CLUSTER_NAME' não está rodando.${NC}"
    exit 1
fi

kubectl config use-context "kind-$CLUSTER_NAME"

# 2. Verificar se o n8n está rodando e pronto
echo "⏳ Verificando se o n8n está pronto no namespace $NAMESPACE..."
kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l app=n8n --timeout=30s

# 3. Estabelecer port-forward temporário se a porta não estiver ouvindo
PORT_FORWARD_PID=""
if ! lsof -i :"$PORT" >/dev/null 2>&1; then
    echo "🌐 Iniciando encaminhamento de porta temporário para $SERVICE_NAME na porta $PORT..."
    kubectl port-forward --namespace "$NAMESPACE" svc/"$SERVICE_NAME" "$PORT":"$PORT" >/dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    sleep 3
else
    echo "ℹ️  Porta $PORT já está ocupada/ativa. Usando conexão existente..."
fi

cleanup() {
    if [ -n "$PORT_FORWARD_PID" ]; then
        echo "🧹 Finalizando port-forward temporário (PID: $PORT_FORWARD_PID)..."
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# 4. Executar o Teste de Carga com ApacheBench (ab)
ENDPOINT="http://127.0.0.1:$PORT/"
CONCURRENCY=10
REQUESTS=200

echo -e "${YELLOW}🚀 Iniciando teste de carga contra $ENDPOINT...${NC}"
echo -e "Enviando $REQUESTS requisições com concorrência de $CONCURRENCY..."

# Armazenar o output em um arquivo temporário
AB_RESULT_FILE=$(mktemp)
ab -n "$REQUESTS" -c "$CONCURRENCY" "$ENDPOINT" > "$AB_RESULT_FILE" 2>&1 || true

cat "$AB_RESULT_FILE"

# 5. Validações de Comportamento BDD (Assertion Phase)
echo -e "\n${BLUE}========================================================================${NC}"
echo -e "${BLUE}🔍 Validando Critérios de Aceitação BDD (Carga)${NC}"
echo -e "${BLUE}========================================================================${NC}"

# Critério 1: Taxa de Sucesso (Zero requisições falhas)
FAILED_REQUESTS=$(grep "Failed requests:" "$AB_RESULT_FILE" | awk '{print $3}' || echo "0")
if [ -z "$FAILED_REQUESTS" ]; then
    FAILED_REQUESTS=0
fi

# Critério 2: Erros de conexão/retorno não-2xx
NON_2XX=$(grep "Non-2xx responses:" "$AB_RESULT_FILE" | awk '{print $3}' || echo "0")
if [ -z "$NON_2XX" ]; then
    NON_2XX=0
fi

# Critério 3: O pod do n8n não deve ter reiniciado (CrashLoopBackOff check)
RESTARTS=$(kubectl get pods -n "$NAMESPACE" -l app=n8n -o jsonpath="{.items[0].status.containerStatuses[0].restartCount}")

echo -e "Requisições Falhas (ab): $FAILED_REQUESTS"
echo -e "Respostas Não-2xx: $NON_2XX"
echo -e "Reinicializações do Pod n8n: $RESTARTS"

TEST_PASSED=true

if [ "$FAILED_REQUESTS" -gt 0 ]; then
    echo -e "${RED}❌ Falha no Critério BDD: Houve $FAILED_REQUESTS requisições falhas.${NC}"
    TEST_PASSED=false
fi

if [ "$NON_2XX" -gt 0 ]; then
    echo -e "${RED}❌ Falha no Critério BDD: Recebemos $NON_2XX respostas HTTP não-2xx.${NC}"
    TEST_PASSED=false
fi

if [ "$RESTARTS" -gt 0 ]; then
    echo -e "${RED}❌ Falha no Critério BDD: O Pod do n8n reiniciou $RESTARTS vezes durante a carga.${NC}"
    TEST_PASSED=false
fi

if [ "$TEST_PASSED" = true ]; then
    echo -e "${GREEN}✅ Teste BDD de Carga passou! O n8n se comportou de forma estável sob carga local.${NC}"
else
    echo -e "${RED}❌ Teste BDD de Carga falhou. Verifique os limites de recursos e logs do n8n.${NC}"
    exit 1
fi
