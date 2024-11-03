#!/bin/bash

# Cores para formatação
AMARELO="\e[33m"
VERDE="\e[32m"
VERMELHO="\e[31m"
BRANCO="\e[97m"
RESET="\e[0m"

# Função para gerar senhas aleatórias
gerar_senha() {
    openssl rand -hex 16
}

# Função para exibir o banner do instalador
mostrar_banner() {
    clear
    echo -e "${AMARELO}=================================================================${RESET}"
    echo -e "${BRANCO}                         NAGE IA INSTALLER                         ${RESET}"
    echo -e "${BRANCO}            Ambiente Completo para Desenvolvimento IA              ${RESET}"
    echo -e "${AMARELO}=================================================================${RESET}"
    echo ""
}

# Função para verificar dependências
verificar_dependencias() {
    echo -e "${AMARELO}[*] Verificando dependências...${RESET}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${VERMELHO}[!] Docker não encontrado. Instalando...${RESET}"
        curl -fsSL https://get.docker.com | bash
        systemctl enable docker
        systemctl start docker
    fi
    
    if ! docker info | grep -q "Swarm: active"; then
        echo -e "${AMARELO}[*] Inicializando Docker Swarm...${RESET}"
        docker swarm init --advertise-addr $(hostname -i | awk '{print $1}') &>/dev/null
    fi
}

# Função para coletar informações
coletar_informacoes() {
    echo -e "${AMARELO}[*] Configuração inicial${RESET}"
    echo ""
    
    # Coletar informações básicas
    read -p "Digite o domínio base (ex: seudominio.com.br): " DOMINIO_BASE
    read -p "Digite seu email para certificados SSL: " EMAIL_SSL
    read -p "Digite o nome da sua empresa: " NOME_EMPRESA
    
    # Configurar subdomínios
    DOMINIO_PORTAINER="painel.${DOMINIO_BASE}"
    DOMINIO_FLOWISE="flowise.${DOMINIO_BASE}"
    DOMINIO_EVOLUTION="api.evolution.${DOMINIO_BASE}"
    DOMINIO_N8N="n8n.${DOMINIO_BASE}"
    DOMINIO_N8N_WEBHOOK="webhook.${DOMINIO_BASE}"
    DOMINIO_QDRANT="qdrant.${DOMINIO_BASE}"
    
    # Gerar senhas
    POSTGRES_PASSWORD=$(gerar_senha)
    REDIS_PASSWORD=$(gerar_senha)
    QDRANT_API_KEY=$(gerar_senha)
    QDRANT_READ_API_KEY=$(gerar_senha)
    FLOWISE_PASSWORD=$(gerar_senha)
    FLOWISE_SECRET_KEY=$(gerar_senha)
    EVOLUTION_API_KEY=$(gerar_senha)
    N8N_ENCRYPTION_KEY=$(gerar_senha)
    
    # Nome da rede
    NOME_REDE="academy_network"
    
    echo -e "${VERDE}[✓] Configurações iniciais coletadas${RESET}"
    echo ""
}

# Função para criar rede
criar_rede() {
    echo -e "${AMARELO}[*] Configurando rede...${RESET}"
    
    if ! docker network ls | grep -q ${NOME_REDE}; then
        docker network create --driver overlay --attachable ${NOME_REDE}
    fi
}

# Função para criar volumes
criar_volumes() {
    echo -e "${AMARELO}[*] Configurando volumes...${RESET}"
    
    volumes=(
        "portainer_data"
        "postgres_data"
        "redis_data"
        "flowise_data"
        "evolution_data"
        "qdrant_storage"
        "qdrant_snapshots"
        "qdrant_tls"
        "volume_swarm_shared"
        "volume_swarm_certificates"
    )
    
    for volume in "${volumes[@]}"; do
        if ! docker volume ls | grep -q ${volume}; then
            docker volume create ${volume}
        fi
    done
}

# Função para criar banco de dados
criar_banco_postgres() {
    local banco=$1
    echo -e "${AMARELO}[*] Criando banco de dados ${banco}...${RESET}"
    
    sleep 30 # Aguardar PostgreSQL inicializar
    
    docker exec $(docker ps -q -f name=postgres) psql -U postgres -c "CREATE DATABASE ${banco};"
}

# Função para instalar Traefik
instalar_traefik() {
    echo -e "${AMARELO}[*] Instalando Traefik...${RESET}"
    
    cat > traefik.yaml <<EOF
version: "3.7"
services:
  traefik:
    image: traefik:latest
    command:
      - "--api.dashboard=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=${NOME_REDE}"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencryptresolver.acme.email=${EMAIL_SSL}"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "vol_certificates:/etc/traefik/letsencrypt"
    networks:
      - ${NOME_REDE}
    ports:
      - 80:80
      - 443:443
    deploy:
      placement:
        constraints:
          - node.role == manager
EOF

    docker stack deploy -c traefik.yaml traefik
}

# Função para instalar PostgreSQL
instalar_postgres() {
    echo -e "${AMARELO}[*] Instalando PostgreSQL...${RESET}"
    
    cat > postgres.yaml <<EOF
version: "3.7"
services:
  postgres:
    image: postgres:latest
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ${NOME_REDE}
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
EOF

    docker stack deploy -c postgres.yaml postgres
}

# Função para instalar Redis
instalar_redis() {
    echo -e "${AMARELO}[*] Instalando Redis...${RESET}"
    
    cat > redis.yaml <<EOF
version: "3.7"
services:
  redis:
    image: redis:latest
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - ${NOME_REDE}
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
EOF

    docker stack deploy -c redis.yaml redis
}

# Função para instalar Flowise
instalar_flowise() {
    echo -e "${AMARELO}[*] Instalando Flowise...${RESET}"
    
    criar_banco_postgres "flowise"
    
    cat > flowise.yaml <<EOF
version: "3.7"
services:
  flowise:
    image: flowiseai/flowise:latest
    environment:
      - FLOWISE_USERNAME=admin@${DOMINIO_BASE}
      - FLOWISE_PASSWORD=${FLOWISE_PASSWORD}
      - DATABASE_TYPE=postgres
      - DATABASE_HOST=postgres
      - DATABASE_PORT=5432
      - DATABASE_USER=postgres
      - DATABASE_PASSWORD=${POSTGRES_PASSWORD}
      - DATABASE_NAME=flowise
      - FLOWISE_SECRETKEY_OVERWRITE=${FLOWISE_SECRET_KEY}
    volumes:
      - flowise_data:/root/.flowise
    networks:
      - ${NOME_REDE}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.flowise.rule=Host(\`${DOMINIO_FLOWISE}\`)
        - traefik.http.routers.flowise.entrypoints=websecure
        - traefik.http.routers.flowise.tls.certresolver=letsencryptresolver
        - traefik.http.services.flowise.loadbalancer.server.port=3000
EOF

    docker stack deploy -c flowise.yaml flowise
}

# Função para instalar Evolution API
instalar_evolution() {
    echo -e "${AMARELO}[*] Instalando Evolution API...${RESET}"
    
    criar_banco_postgres "evolution"
    
    cat > evolution.yaml <<EOF
version: "3.7"
services:
  evolution:
    image: atendai/evolution-api:v2.1.1
    environment:
      - SERVER_URL=https://${DOMINIO_EVOLUTION}
      - AUTHENTICATION_API_KEY=${EVOLUTION_API_KEY}
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/evolution
    networks:
      - ${NOME_REDE}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\`${DOMINIO_EVOLUTION}\`)
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.services.evolution.loadbalancer.server.port=8080
EOF

    docker stack deploy -c evolution.yaml evolution
}

# Função para instalar N8N
instalar_n8n() {
    echo -e "${AMARELO}[*] Instalando N8N...${RESET}"
    
    criar_banco_postgres "n8n"
    
    # N8N Editor
    cat > n8n-editor.yaml <<EOF
version: "3.7"
services:
  n8n_editor:
    image: n8nio/n8n:latest
    command: start
    networks:
      - ${NOME_REDE}
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_HOST=${DOMINIO_N8N}
      - N8N_EDITOR_BASE_URL=https://${DOMINIO_N8N}/
      - WEBHOOK_URL=https://${DOMINIO_N8N_WEBHOOK}/
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n_editor.rule=Host(\`${DOMINIO_N8N}\`)
        - traefik.http.routers.n8n_editor.entrypoints=websecure
        - traefik.http.routers.n8n_editor.tls.certresolver=letsencryptresolver
        - traefik.http.services.n8n_editor.loadbalancer.server.port=5678
EOF

    # N8N Webhook
    cat > n8n-webhook.yaml <<EOF
version: "3.7"
services:
  n8n_webhook:
    image: n8nio/n8n:latest
    command: webhook
    networks:
      - ${NOME_REDE}
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_HOST=${DOMINIO_N8N}
      - N8N_EDITOR_BASE_URL=https://${DOMINIO_N8N}/
      - WEBHOOK_URL=https://${DOMINIO_N8N_WEBHOOK}/
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n_webhook.rule=Host(\`${DOMINIO_N8N_WEBHOOK}\`)
        - traefik.http.routers.n8n_webhook.entrypoints=websecure
        - traefik.http.routers.n8n_webhook.tls.certresolver=letsencryptresolver
        - traefik.http.services.n8n_webhook.loadbalancer.server.port=5678
EOF

    # N8N Workers
    cat > n8n-workers.yaml <<EOF
version: "3.7"
services:
  n8n_worker:
    image: n8nio/n8n:latest
    command: worker --concurrency=10
    networks:
      - ${NOME_REDE}
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_