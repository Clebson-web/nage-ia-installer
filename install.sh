#!/bin/bash

# Cores para output
AMARELO="\033[33m"
VERDE="\033[32m"
RESET="\033[0m"

# Banner
echo -e "${AMARELO}=================================================================${RESET}"
echo -e "${AMARELO}                         NAGE IA INSTALLER                         ${RESET}"
echo -e "${AMARELO}=================================================================${RESET}"
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute como root (use sudo)"
    exit
fi

# Verificar sistema operacional
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "Este instalador foi projetado para Ubuntu. Outros sistemas podem não funcionar corretamente."
    read -p "Deseja continuar mesmo assim? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Criar diretório temporário
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Baixar instalador principal
echo -e "${AMARELO}Baixando instalador...${RESET}"
wget -q https://raw.githubusercontent.com/Clebson-web/nage-ia-installer/main/nage-ia.sh

# Dar permissão de execução
chmod +x nage-ia.sh

# Executar instalador
./nage-ia.sh

# Limpar arquivos temporários
cd
rm -rf "$TMP_DIR"
