#!/bin/bash

# Cores
AMARELO="\033[33m"
VERDE="\033[32m"
VERMELHO="\033[31m"
RESET="\033[0m"

echo -e "${AMARELO}=================================================================${RESET}"
echo -e "${AMARELO}                         NAGE IA INSTALLER                         ${RESET}"
echo -e "${AMARELO}=================================================================${RESET}"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${VERMELHO}Por favor, execute como root (use sudo)${RESET}"
    exit
fi

# Atualizar sistema
echo -e "${AMARELO}[*] Atualizando sistema...${RESET}"
apt-get update && apt-get upgrade -y

# Instalar dependências
echo -e "${AMARELO}[*] Instalando dependências...${RESET}"
apt-get install -y curl wget git apt-transport-https ca-certificates gnupg-agent software-properties-common ufw fail2ban net-tools unzip jq

# Instalar Docker
if ! command -v docker &> /dev/null; then
    echo -e "${AMARELO}[*] Instalando Docker...${RESET}"
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
fi

# Configurar Docker Swarm
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${AMARELO}[*] Configurando Docker Swarm...${RESET}"
    docker swarm init --advertise-addr $(hostname -i | awk '{print $1}')
fi

# Criar rede
if ! docker network ls | grep -q "nage_network"; then
    echo -e "${AMARELO}[*] Criando rede Docker...${RESET}"
    docker network create --driver overlay --attachable nage_network
fi

# Configurar volumes
echo -e "${AMARELO}[*] Configurando volumes...${RESET}"
volumes=(
    "portainer_data"
    "postgres_data"
    "redis_data"
    "flowise_data"
    "evolution_data"
    "volume_swarm_shared"
    "volume_swarm_certificates"
)

for volume in "${volumes[@]}"; do
    if ! docker volume ls | grep -q ${volume}; then
        docker volume create ${volume}
    fi
done

# Coletar informações
echo -e "${AMARELO}[*] Configuração inicial${RESET}"
read -p "Digite o domínio base (ex: seudominio.com.br): " DOMINIO_BASE
read -p "Digite seu email para certificados SSL: " EMAIL_SSL

# Gerar senhas
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -hex 16)
EVOLUTION_API_KEY=$(openssl rand -hex 16)

# Salvar credenciais
mkdir -p ~/nage-credentials
echo "NAGE IA - Credenciais" > ~/nage-credentials/credentials.txt
echo "========================" >> ~/nage-credentials/credentials.txt
echo "PostgreSQL Password: ${POSTGRES_PASSWORD}" >> ~/nage-credentials/credentials.txt
echo "Redis Password: ${REDIS_PASSWORD}" >> ~/nage-credentials/credentials.txt
echo "Evolution API Key: ${EVOLUTION_API_KEY}" >> ~/nage-credentials/credentials.txt
echo "Domínio Base: ${DOMINIO_BASE}" >> ~/nage-credentials/credentials.txt
echo "Email SSL: ${EMAIL_SSL}" >> ~/nage-credentials/credentials.txt

echo -e "${VERDE}[✓] Preparação concluída!${RESET}"
echo -e "${AMARELO}Credenciais salvas em: ~/nage-credentials/credentials.txt${RESET}"

# Baixar e executar scripts específicos
wget -q https://raw.githubusercontent.com/Clebson-web/nage-ia-installer/main/stacks/traefik.sh -O /root/traefik.sh
wget -q https://raw.githubusercontent.com/Clebson-web/nage-ia-installer/main/stacks/postgres.sh -O /root/postgres.sh
wget -q https://raw.githubusercontent.com/Clebson-web/nage-ia-installer/main/stacks/redis.sh -O /root/redis.sh
wget -q https://raw.githubusercontent.com/Clebson-web/nage-ia-installer/main/stacks/flowise.sh -O /root/flowise.sh
wget -q https://raw.githubusercontent.com/Clebson-web/nage-ia-installer/main/stacks/evolution.sh -O /root/evolution.sh

chmod +x /root/*.sh

# Executar instalações
bash /root/traefik.sh
bash /root/postgres.sh
bash /root/redis.sh
bash /root/flowise.sh
bash /root/evolution.sh

echo -e "${VERDE}[✓] Instalação concluída!${RESET}"
echo -e "${AMARELO}Acesse seus serviços em:${RESET}"
echo -e "Portainer: https://painel.${DOMINIO_BASE}"
echo -e "Flowise: https://flowise.${DOMINIO_BASE}"
echo -e "Evolution API: https://api.evolution.${DOMINIO_BASE}"
