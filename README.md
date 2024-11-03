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

## Instalação Rápida

```bash
curl -fsSL https://raw.githubusercontent.com/Clebson-web/nage-ia-installer/main/install.sh | sudo bash
```

## Requisitos

- Ubuntu 20.04 ou superior
- Domínio configurado apontando para o servidor
- Portas 80 e 443 liberadas

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
sudo ./install.sh
```

## O que será instalado

### Dependências do Sistema
- curl, wget, git
- apt-transport-https
- ca-certificates
- gnupg-agent
- software-properties-common
- ufw (firewall)
- fail2ban (segurança)
- net-tools
- unzip
- jq

### Ferramentas de IA
- Traefik (Proxy Reverso com SSL automático)
- Portainer (Gerenciamento de Containers)
- PostgreSQL (Banco de Dados)
- Redis (Cache)
- Flowise (Fluxos de IA)
- N8N (Automação)
- Evolution API (WhatsApp API)
- Qdrant (Vector Database)

## Após a Instalação

- Credenciais e informações de acesso: `~/nage-credentials/credentials.txt`
- Logs de instalação: `~/nage-logs/install.log`
- Stacks Docker: `/root/nage-stacks/`

## URLs de Acesso

Após a instalação, você terá acesso às seguintes interfaces:

- Portainer: https://painel.seudominio.com
- Flowise: https://flowise.seudominio.com
- N8N: https://n8n.seudominio.com
- Evolution API: https://api.evolution.seudominio.com

## Segurança

O instalador configura automaticamente:
- Firewall (ufw) com apenas portas essenciais
- Fail2ban para proteção contra ataques
- SSL/TLS automático via Let's Encrypt
- Senhas aleatórias para todos os serviços

## Suporte

Para suporte:
1. Abra uma issue em: https://github.com/Clebson-web/nage-ia-installer/issues
2. Forneça os logs de instalação localizados em `~/nage-logs/install.log`
3. Descreva detalhadamente o problema encontrado

## Contribuindo

Contribuições são bem-vindas! Por favor:
1. Faça um fork do repositório
2. Crie uma branch para sua feature
3. Faça suas alterações
4. Envie um Pull Request

## Licença

MIT License - veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## Autor

Mantido por [Clebson-web](https://github.com/Clebson-web)
