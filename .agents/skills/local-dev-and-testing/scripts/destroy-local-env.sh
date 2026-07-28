#!/usr/bin/env bash

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="local-platform"

echo -e "${RED}========================================================================${NC}"
echo -e "${RED}🧹 Destruindo Ambiente de Desenvolvimento Local (ADR 0006)${NC}"
echo -e "${RED}========================================================================${NC}"

if command -v kind &> /dev/null && kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "🗑️  Destruindo cluster Kind '$CLUSTER_NAME'..."
    kind delete cluster --name "$CLUSTER_NAME"
else
    echo -e "${YELLOW}ℹ️  Nenhum cluster Kind com o nome '$CLUSTER_NAME' ativo.${NC}"
fi

echo -e "${YELLOW}-> Deseja executar limpeza profunda de resíduos no Docker? (imagens e volumes órfãos) [y/N]:${NC}"
read -r CONFIRM_CLEAN
if [[ "$CONFIRM_CLEAN" =~ ^[Yy]$ ]]; then
    echo "🧹 Executando docker system prune..."
    docker system prune -a --volumes --force
fi

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}✨ Limpeza local concluída!${NC}"
echo -e "${GREEN}========================================================================${NC}"
