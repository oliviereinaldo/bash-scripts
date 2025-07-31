#!/bin/bash

# ================================
# CONFIGURAÇÕES (ajuste conforme o site)
# ================================
NOME_SITE="meusite"
DOMINIO="meusite.com"
DOMINIO_WWW="www.meusite.com"
SITE_DIR="/var/www/$NOME_SITE"
VENV_DIR="$SITE_DIR/venv_${NOME_SITE}"
LOG_PATH="/var/log/${NOME_SITE}"
CONFIG_PATH="/etc/config_${NOME_SITE}"
SERVICE_NAME="$NOME_SITE"
NGINX_CONF="/etc/nginx/sites-available/${DOMINIO}"

echo "🧹 Iniciando remoção do site $NOME_SITE ($DOMINIO)"

# ================================
# PARA E DESABILITA O SERVIÇO GUNICORN
# ================================
echo "⛔ Parando serviço $SERVICE_NAME..."
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || echo "Serviço já parado ou inexistente."
sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || echo "Serviço já desabilitado ou inexistente."

# Remove arquivo do systemd
echo "🗑️  Removendo arquivo de serviço systemd..."
sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"

# Recarrega systemd
sudo systemctl daemon-reload

# ================================
# REMOVE CONFIGURAÇÃO DO NGINX
# ================================
echo "🗑️  Removendo configuração do Nginx..."
sudo rm -f "$NGINX_CONF"
sudo rm -f "/etc/nginx/sites-enabled/${DOMINIO}"
sudo rm -f "/etc/nginx/sites-enabled/default" 2>/dev/null

# Recarrega o Nginx para aplicar alterações
sudo nginx -t && sudo systemctl reload nginx

# ================================
# REMOVE CERTIFICADO SSL LET'S ENCRYPT
# ================================
echo "🔐 Preservando certificado SSL Let's Encrypt existente."
#echo "🔐 Removendo certificado SSL Let's Encrypt..."
#sudo certbot delete --cert-name "$DOMINIO" --non-interactive || echo "⚠️ Certbot delete falhou ou certificado não existe."

# ================================
# REMOVE AMBIENTE VIRTUAL
# ================================
echo "🧽 Removendo ambiente virtual..."

# Encerra venv se estiver ativa
if [[ "$VIRTUAL_ENV" == "$VENV_DIR" ]]; then
    echo "⚠️  Ambiente virtual está ativo. Encerrando..."
    deactivate || echo "Não foi possível desativar virtualenv (pode não estar ativa no contexto do script)."
fi

# Mata processos que ainda estejam usando a venv (ex: gunicorn zumbi)
# Verifica e mata processos usando a venv
echo "🔍 Verificando processos que usam o ambiente virtual..."
PIDS=$(lsof +D "$VENV_DIR" 2>/dev/null | awk '{print $2}' | grep -E '^[0-9]+$' | sort -u)
if [[ -n "$PIDS" ]]; then
    echo "⚠️  Matando processos que usam a venv: $PIDS"
    sudo kill -9 $PIDS
    sleep 2
fi

# Aguarda brevemente para garantir liberação do sistema de arquivos
sleep 2

# Remove a venv
sudo rm -rf "$VENV_DIR"

if [ -d "$VENV_DIR" ]; then
    echo "❌ Falha ao remover o ambiente virtual $VENV_DIR"
else
    echo "✅ Ambiente virtual removido com sucesso."
fi

# ================================
# REMOVE ARQUIVOS DO PROJETO, LOGS E CONFIGURAÇÃO
# ================================
echo "🗑️  Removendo diretórios do projeto, logs e configs..."
sudo rm -rf "$SITE_DIR"
sudo rm -rf "$LOG_PATH"
sudo rm -rf "$CONFIG_PATH"

echo -e "\n✅ Remoção do site '$NOME_SITE' concluída com sucesso.\n"
