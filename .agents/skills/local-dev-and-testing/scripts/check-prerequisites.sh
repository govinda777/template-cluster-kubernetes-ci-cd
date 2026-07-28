#!/usr/bin/env bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_docker_install_guide() {
    echo -e "${YELLOW}========================================================================${NC}"
    echo -e "${BLUE}🐳 GUIA DE INSTALAÇÃO DO DOCKER NO MACOS${NC}"
    echo -e "${YELLOW}========================================================================${NC}"
    echo -e "Instalar o Docker no Mac é bem simples! O processo leva apenas alguns minutos.\n"
    echo -e "Como checar o processador do seu Mac:"
    echo -e "   Clique no ícone da Maçã () no canto superior esquerdo → Sobre Este Mac."
    echo -e "   Em \"Chip\" ou \"Processador\", veja se diz Apple M-series (Silicon) ou Intel.\n"
    echo -e "Passo a Passo de Instalação:"
    echo -e "   1. Baixar o instalador correto:"
    echo -e "      Acesse o site oficial do Docker Desktop para Mac e escolha o botão correspondente:"
    echo -e "      - Mac com Apple Silicon (chips M1, M2, M3, M4, etc.)"
    echo -e "      - Mac com Intel chip (Macs mais antigos)"
    echo -e "   2. Instalar o aplicativo:"
    echo -e "      Abra o arquivo .dmg baixado e arraste o Docker para a pasta Aplicações."
    echo -e "   3. Primeira execução e permissões:"
    echo -e "      Abra o Docker. Aceite o contrato de uso, selecione \"Use recommended settings\" e confirme."
    echo -e "   4. Verificar se está funcionando:"
    echo -e "      Abra o Terminal e execute:"
    echo -e "         ${GREEN}docker --version${NC}\n"
    echo -e "💡 Dica Importante para Macs com Apple Silicon (Chips M):"
    echo -e "   É altamente recomendável instalar o Rosetta 2 para rodar containers x86 antigos."
    echo -e "   Execute no Terminal:"
    echo -e "      ${GREEN}softwareupdate --install-rosetta${NC}"
    echo -e "${YELLOW}========================================================================${NC}"
}

check_prereqs() {
    local exit_code=0

    # 1. Validar Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Erro: O Docker não está instalado ou não está no seu PATH.${NC}"
        show_docker_install_guide
        exit_code=1
    fi

    # 2. Validar outras ferramentas
    for cmd in kind kubectl kustomize; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}❌ Erro: O comando '$cmd' não foi encontrado.${NC}"
            echo -e "   Instale via Homebrew: ${GREEN}brew install $cmd${NC}"
            exit_code=1
        fi
    done

    return $exit_code
}

check_prereqs
