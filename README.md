# NAGE IA Installer

Instalador automático para ambiente de desenvolvimento de IA, incluindo:

- Traefik (Proxy Reverso)
- Portainer (Gerenciamento de Containers)
- PostgreSQL (Banco de Dados)
- Redis (Cache)
- Flowise (Fluxos de IA)
- N8N (Automação)
- Evolution API (WhatsApp API)
- Qdrant (Vector Database)

## Requisitos

- Ubuntu 20.04 ou superior
- Domínio configurado apontando para o servidor
- Portas 80 e 443 liberadas

## Instalação Rápida

```bash
curl -fsSL https://raw.githubusercontent.com/Clebson-web/nage-ia-installer/main/install.sh | bash
```

## Instalação Manual

1. Baixe o instalador:
```bash
wget https://raw.githubusercontent.com/Clebson-web/nage-ia-installer/main/install.sh
```

2. Dê permissão de execução:
```bash
chmod +x install.sh
```

3. Execute o instalador:
```bash
./install.sh
```

## Após a Instalação

O instalador irá salvar todas as credenciais em:
```
~/nage-credentials/credentials.txt
```

## URLs de Acesso

- Portainer: https://painel.seudominio.com
- Flowise: https://flowise.seudominio.com
- N8N: https://n8n.seudominio.com
- Evolution API: https://api.evolution.seudominio.com

## Suporte

Para suporte, abra uma issue no GitHub.

## Licença

MIT
