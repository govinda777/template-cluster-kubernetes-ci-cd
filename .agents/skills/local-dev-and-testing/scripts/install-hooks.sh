#!/usr/bin/env bash

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

HOOKS_DIR=".git/hooks"

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}🔧 Instalando Git Hooks Locais para o DoD${NC}"
echo -e "${BLUE}========================================================================${NC}"

if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Erro: Este diretório não é um repositório git ativo.${NC}"
    exit 1
fi

# 1. Instalar Hook Pre-commit
echo "📦 Configurando pre-commit hook..."
cat <<'EOF' > "$HOOKS_DIR/pre-commit"
#!/usr/bin/env bash
bash .agents/skills/local-dev-and-testing/scripts/run-unit-tests.sh
EOF
chmod +x "$HOOKS_DIR/pre-commit"
echo -e "${GREEN}✅ pre-commit configurado com sucesso! (Executa testes unitários/static checks)${NC}"

# 2. Instalar Hook Pre-push
echo "📦 Configurando pre-push hook..."
cat <<'EOF' > "$HOOKS_DIR/pre-push"
#!/usr/bin/env bash
bash .agents/skills/local-dev-and-testing/scripts/run-bdd-tests.sh
EOF
chmod +x "$HOOKS_DIR/pre-push"
echo -e "${GREEN}✅ pre-push configurado com sucesso! (Executa BDD local em Kind)${NC}"

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}🎉 Hooks de Git instalados com sucesso! DoD automatizado.${NC}"
echo -e "${GREEN}========================================================================${NC}"
