#!/bin/bash

# Cores
AMARELO="\033[33m"
VERDE="\033[32m"
VERMELHO="\033[31m"
RESET="\033[0m"

# Banner
echo -e "${AMARELO}=================================================================${RESET}"
echo -e "${AMARELO}                         NAGE IA INSTALLER                         ${RESET}"
echo -e "${AMARELO}=================================================================${RESET}"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${VERMELHO}Por favor, execute como root (use sudo)${RESET}"
    exit
fi

# Configuração inicial
echo -e "${AMARELO}[*] Configuração inicial${RESET}"
read -p "Digite o domínio base (ex: seudominio.com.br): " DOMINIO_BASE
read -p "Digite seu email para certificados SSL: " EMAIL_SSL

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
echo -e "${AMARELO}[*] Configurando Docker Swarm...${RESET}"
if ! docker info | grep -q "Swarm: active"; then
    docker swarm init --advertise-addr $(hostname -i | awk '{print $1}')
fi

# Criar rede
echo -e "${AMARELO}[*] Criando rede Docker...${RESET}"
docker network create --driver overlay --attachable nage_network

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
    docker volume create ${volume}
done

# Gerar senhas
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -hex 16)
EVOLUTION_API_KEY=$(openssl rand -hex 16)

# Criar diretório para stacks
mkdir -p /root/nage-stacks

# Traefik Stack
cat > /root/nage-stacks/traefik.yaml <<'EOF'
version: "3.7"
services:
  traefik:
    image: traefik:latest
    command:
      - "--api.dashboard=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=nage_network"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "volume_swarm_certificates:/etc/traefik/letsencrypt"
    networks:
      - nage_network
    ports:
      - 80:80
      - 443:443
    deploy:
      placement:
        constraints:
          - node.role == manager
    environment:
      - "CERTIFICATESRESOLVERS_LETSENCRYPTRESOLVER_ACME_EMAIL=${EMAIL_SSL}"

networks:
  nage_network:
    external: true
EOF

# Portainer Stack
cat > /root/nage-stacks/portainer.yaml <<'EOF'
version: "3.7"
services:
  agent:
    image: portainer/agent:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks:
      - nage_network
    deploy:
      mode: global
      placement:
        constraints: [node.platform.os == linux]

  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://tasks.agent:9001 --tlsskipverify
    volumes:
      - portainer_data:/data
    networks:
      - nage_network
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.portainer.rule=Host(`painel.${DOMINIO_BASE}`)"
        - "traefik.http.routers.portainer.entrypoints=websecure"
        - "traefik.http.routers.portainer.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"

networks:
  nage_network:
    external: true

volumes:
  portainer_data:
    external: true
EOF

# PostgreSQL Stack
cat > /root/nage-stacks/postgres.yaml <<'EOF'
version: "3.7"
services:
  postgres:
    image: postgres:latest
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - nage_network
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M

networks:
  nage_network:
    external: true

volumes:
  postgres_data:
    external: true
EOF

# Redis Stack
cat > /root/nage-stacks/redis.yaml <<'EOF'
version: "3.7"
services:
  redis:
    image: redis:latest
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - nage_network
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M

networks:
  nage_network:
    external: true

volumes:
  redis_data:
    external: true
EOF

# Flowise Stack
cat > /root/nage-stacks/flowise.yaml <<'EOF'
version: "3.7"
services:
  flowise:
    image: flowiseai/flowise:latest
    volumes:
      - flowise_data:/root/.flowise
    networks:
      - nage_network
    environment:
      - DATABASE_TYPE=postgres
      - DATABASE_HOST=postgres
      - DATABASE_PORT=5432
      - DATABASE_USER=postgres
      - DATABASE_PASSWORD=${POSTGRES_PASSWORD}
      - DATABASE_NAME=flowise
      - REDIS_URL=redis://redis:6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.flowise.rule=Host(`flowise.${DOMINIO_BASE}`)"
        - "traefik.http.routers.flowise.entrypoints=websecure"
        - "traefik.http.routers.flowise.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.flowise.loadbalancer.server.port=3000"

networks:
  nage_network:
    external: true

volumes:
  flowise_data:
    external: true
EOF

# Evolution API Stack
cat > /root/nage-stacks/evolution.yaml <<'EOF'
version: "3.7"
services:
  evolution:
    image: atendai/evolution-api:v2.1.1
    networks:
      - nage_network
    environment:
      - SERVER_URL=https://api.evolution.${DOMINIO_BASE}
      - AUTHENTICATION_API_KEY=${EVOLUTION_API_KEY}
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/evolution
      - REDIS_URI=redis://redis:6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.evolution.rule=Host(`api.evolution.${DOMINIO_BASE}`)"
        - "traefik.http.routers.evolution.entrypoints=websecure"
        - "traefik.http.routers.evolution.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.evolution.loadbalancer.server.port=8080"

networks:
  nage_network:
    external: true

volumes:
  evolution_data:
    external: true
EOF

# Substituir variáveis nos arquivos
sed -i "s/\${EMAIL_SSL}/$EMAIL_SSL/g" /root/nage-stacks/traefik.yaml
sed -i "s/\${DOMINIO_BASE}/$DOMINIO_BASE/g" /root/nage-stacks/*.yaml
sed -i "s/\${POSTGRES_PASSWORD}/$POSTGRES_PASSWORD/g" /root/nage-stacks/*.yaml
sed -i "s/\${REDIS_PASSWORD}/$REDIS_PASSWORD/g" /root/nage-stacks/*.yaml
sed -i "s/\${EVOLUTION_API_KEY}/$EVOLUTION_API_KEY/g" /root/nage-stacks/*.yaml

# Deploy das stacks em ordem
echo -e "${AMARELO}[*] Implantando serviços...${RESET}"

# Deploy Traefik e aguardar
docker stack deploy -c /root/nage-stacks/traefik.yaml traefik
echo "Aguardando Traefik inicializar..."
sleep 30

# Deploy Portainer
docker stack deploy -c /root/nage-stacks/portainer.yaml portainer
sleep 10

# Deploy PostgreSQL
docker stack deploy -c /root/nage-stacks/postgres.yaml postgres
sleep 20

# Deploy Redis
docker stack deploy -c /root/nage-stacks/redis.yaml redis
sleep 10

# Deploy Flowise
docker stack deploy -c /root/nage-stacks/flowise.yaml flowise
sleep 10

# Deploy Evolution API
docker stack deploy -c /root/nage-stacks/evolution.yaml evolution

# Criar bancos de dados necessários
echo "Criando bancos de dados..."
sleep 30

# Salvar credenciais
mkdir -p ~/nage-credentials
cat > ~/nage-credentials/credentials.txt <<EOL
NAGE IA - Credenciais
========================
PostgreSQL Password: ${POSTGRES_PASSWORD}
Redis Password: ${REDIS_PASSWORD}
Evolution API Key: ${EVOLUTION_API_KEY}
Domínio Base: ${DOMINIO_BASE}
Email SSL: ${EMAIL_SSL}

URLs de Acesso:
Portainer: https://painel.${DOMINIO_BASE}
Flowise: https://flowise.${DOMINIO_BASE}
Evolution API: https://api.evolution.${DOMINIO_BASE}
EOL

echo -e "${VERDE}[✓] Instalação concluída!${RESET}"
echo -e "${AMARELO}Credenciais salvas em: ~/nage-credentials/credentials.txt${RESET}"
echo -e "${AMARELO}Acesse seus serviços em:${RESET}"
echo -e "Portainer: https://painel.${DOMINIO_BASE}"
echo -e "Flowise: https://flowise.${DOMINIO_BASE}"
echo -e "Evolution API: https://api.evolution.${DOMINIO_BASE}"
