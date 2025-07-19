#!/bin/bash

clear
cat << "EOF"
    _         _                   _   _             
   / \  _   _| |_ ___  _ __ ___  | |_| |__   ___    
  / _ \| | | | __/ _ \| '__/ _ \ | __| '_ \ / _ \   
 / ___ \ |_| | || (_) | | |  __/ | |_| | | |  __/   
/_/   \_\__,_|\__\___/|_|  \___|  \__|_| |_|\___|   

            A U T O M A T I O N   S I T E
----------------------------------------------------
- Setup automático de projetos Django em VPS
- Nginx + Gunicorn configurados automaticamente
- Banco de dados MySQL provisionado
- Geração dinâmica de configs e estrutura
----------------------------------------------------
 Autor: Olivier Reinaldo         Data: $(date '+%d/%m/%Y')
EOF

echo
# ================================
# CONFIGURAÇÕES INICIAIS INTERATIVAS
# ================================

while true; do
  # Limpa as variáveis para garantir um novo ciclo limpo
  unset NOME_SITE DOMINIO DOMINIO_WWW APP PROJETO SERVICE_NAME DB_NAME DB_USER DB_PASS

  echo "=== Configurações do site ==="
  read -p "Nome do site (ex: meusite): " NOME_SITE
  read -p "Domínio principal (ex: meusite.com): " DOMINIO
  read -p "Domínio www (ex: www.meusite.com): " DOMINIO_WWW
  read -p "Nome do app Django (ex: meusite): " APP
  read -p "Nome do projeto Django (ex: core): " PROJETO
  read -p "Nome do serviço (ex: meusite): " SERVICE_NAME

  echo
  echo "=== Configurações do banco de dados ==="
  read -p "Nome do banco de dados (ex: meubanco): " DB_NAME
  read -p "Usuário do banco (ex: usuario): " DB_USER
  read -sp "Senha do banco (ex: senha): " DB_PASS
  echo

  # Loop para revisão e correção
  while true; do
    echo
    echo "Resumo das configurações:"
    echo "1) Nome do site:       $NOME_SITE"
    echo "2) Domínio principal:  $DOMINIO"
    echo "3) Domínio www:        $DOMINIO_WWW"
    echo "4) Nome do app Django: $APP"
    echo "5) Nome do projeto:    $PROJETO"
    echo "6) Nome do serviço:    $SERVICE_NAME"
    echo "7) Nome do banco:      $DB_NAME"
    echo "8) Usuário do banco:   $DB_USER"
    echo "9) Senha do banco:     $( [ -z "$DB_PASS" ] && echo "(vazio)" || echo "********" )"

    echo
    echo "Digite:"
    echo " c - Confirmar e continuar"
    echo " r - Reiniciar todas as configurações"
    echo " 1-9 - Corrigir o campo correspondente"
    read -p "Sua escolha: " OPC

    case "$OPC" in
      c|C)
        echo "Configurações confirmadas."
        break 2  # Sai dos dois loops, finalizando
        ;;
      r|R)
        echo "Reiniciando configurações..."
        break   # Sai do loop de revisão e volta para o início do while externo
        ;;
      1)
        read -p "Novo valor para Nome do site: " NOME_SITE
        ;;
      2)
        read -p "Novo valor para Domínio principal: " DOMINIO
        ;;
      3)
        read -p "Novo valor para Domínio www: " DOMINIO_WWW
        ;;
      4)
        read -p "Novo valor para Nome do app Django: " APP
        ;;
      5)
        read -p "Novo valor para Nome do projeto: " PROJETO
        ;;
      6)
        read -p "Novo valor para Nome do serviço: " SERVICE_NAME
        ;;
      7)
        read -p "Novo valor para Nome do banco de dados: " DB_NAME
        ;;
      8)
        read -p "Novo valor para Usuário do banco: " DB_USER
        ;;
      9)
        read -sp "Nova senha do banco: " DB_PASS
        echo
        ;;
      *)
        echo "Opção inválida. Tente novamente."
        ;;
    esac
  done
done

echo "Iniciando processo com as configurações:"
echo "Site: $NOME_SITE, Domínio: $DOMINIO, App: $APP, Projeto: $PROJETO"

# Verificar se o Python3 está instalado
if ! command -v python3 &>/dev/null; then
  echo "Erro: Python3 não encontrado. Instale o Python3 para continuar."
  exit 1
fi

# Verificar se o pip está instalado
if ! command -v pip3 &>/dev/null; then
  echo "pip3 não encontrado. Instalando..."
  sudo apt update
  sudo apt install python3-pip -y
  if ! command -v pip3 &>/dev/null; then
    echo "Erro: Falha ao instalar o pip3. Instale manualmente para continuar."
    exit 1
  fi
fi

# Verificar se o Django está instalado, se não, instalar automaticamente
if ! python3 -c "import django" &>/dev/null; then
  echo "Django não está instalado. Instalando Django via apt..."
  sudo apt update
  sudo apt install -y python3-django
  if [ $? -ne 0 ]; then
    echo "Erro na instalação do Django via apt. Verifique sua conexão e permissões."
    exit 1
  fi
  echo "Django instalado com sucesso via apt."
fi

# Gerar automaticamente a chave secreta do Django, se não fornecida
read -p "Chave secreta Django (pressione Enter para gerar automaticamente): " SECRET_KEY_DJANGO

if [ -z "$SECRET_KEY_DJANGO" ]; then
  SECRET_KEY_DJANGO=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
  echo "Chave gerada automaticamente."
fi

echo "Chave secreta: $SECRET_KEY_DJANGO"

SITE_DIR="/var/www/$NOME_SITE"
CONFIG_PATH="/etc/config_${NOME_SITE}"
CONFIG_FILE="${CONFIG_PATH}/${NOME_SITE}.config"
LOG_PATH="/var/log/${NOME_SITE}"

# ================================
# VERIFICAÇÃO DE ROOT
# ================================
if [ "$EUID" -ne 0 ]; then
  echo "Por favor execute como root ou usando sudo."
  exit 1
fi

# ================================
# ATUALIZA PACOTES E INSTALA DEPENDÊNCIAS BÁSICAS
# ================================
echo "Atualizando repositórios e pacotes..."
apt update -y && apt upgrade -y

# ================================
# INSTALAÇÃO DO NGINX (se não instalado)
# ================================
if ! command -v nginx &> /dev/null; then
  echo "Instalando Nginx..."
  apt install nginx -y
  systemctl enable nginx
  systemctl start nginx
else
  echo "Nginx já instalado."
fi

# ================================
# INSTALAÇÃO DO MYSQL (se não instalado)
# ================================
if ! command -v mysql &> /dev/null; then
  echo "Instalando MySQL Server..."
  apt install mysql-server -y
  systemctl enable mysql
  systemctl start mysql
else
  echo "MySQL já instalado."
fi
# ================================
# INSTALAÇÃO DO GIT (se não instalado)
# ================================
if ! command -v git &> /dev/null; then
  echo "Instalando Git..."
  apt update
  apt install git -y
else
  echo "Git já instalado."
fi

# ================================
# INSTALAÇÃO DO GITHUB CLI (opcional, para facilitar uso do GitHub)
# ================================
if ! command -v gh &> /dev/null; then
  echo "Instalando GitHub CLI..."
  type -p curl >/dev/null || apt install curl -y
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  apt update
  apt install gh -y
else
  echo "GitHub CLI já instalado."
fi

# ================================
# CONFIGURAÇÃO DO BANCO MYSQL E USUÁRIO
# ================================
echo "Configurando banco de dados MySQL..."

# Comando SQL para criar banco e usuário, se não existirem
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "Banco e usuário configurados."

# ================================
# CRIA DIRETÓRIO DO PROJETO SE NÃO EXISTIR
# ================================
if [ ! -d "$SITE_DIR" ]; then
  echo "Criando diretório do projeto..."
  mkdir -p "$SITE_DIR"
else
  echo "Diretório do projeto já existe."
fi
cd "$SITE_DIR" || exit 1

# ================================
# GARANTE QUE O PYTHON VENV ESTÁ DISPONÍVEL
# ================================
if ! python3 -m venv --help >/dev/null 2>&1; then
  echo "Módulo venv não disponível. Instalando pacote python3-venv..."
  sudo apt update
  sudo apt install -y python3-venv
fi

# ================================
# CRIA E ATIVA AMBIENTE VIRTUAL PYTHON
# ================================
if [ ! -d "venv_${NOME_SITE}" ]; then
  echo "Criando ambiente virtual Python..."
  python3 -m venv "venv_${NOME_SITE}"
else
  echo "Ambiente virtual já existe."
fi

PIP="$SITE_DIR/venv_${NOME_SITE}/bin/pip"
PYTHON="$SITE_DIR/venv_${NOME_SITE}/bin/python"
DJANGO_ADMIN="$SITE_DIR/venv_${NOME_SITE}/bin/django-admin"

# ================================
# INSTALA DEPENDÊNCIAS PYTHON NO AMBIENTE
# ================================
echo "Instalando Django, mysqlclient e gunicorn..."
"$PIP" install --upgrade pip
"$PIP" install django mysqlclient gunicorn

# ================================
# CRIA O PROJETO DJANGO SE NÃO EXISTIR
# ================================
if [ ! -f "$SITE_DIR/manage.py" ]; then
  echo "Criando projeto Django..."
  "$DJANGO_ADMIN" startproject "$PROJETO" .
else
  echo "Projeto Django já existe."
fi

SETTINGS="$SITE_DIR/$PROJETO/settings.py"

# ================================
# AJUSTA DEBUG E ALLOWED_HOSTS NO settings.py
# ================================
sed -i "s/^DEBUG = True/DEBUG = False/" "$SETTINGS"

if ! grep -q "^ALLOWED_HOSTS" "$SETTINGS"; then
    echo -e "\nALLOWED_HOSTS = ['$DOMINIO', '$DOMINIO_WWW']" >> "$SETTINGS"
else
    sed -i "s/^ALLOWED_HOSTS.*/ALLOWED_HOSTS = ['$DOMINIO', '$DOMINIO_WWW']/" "$SETTINGS"
fi

# ================================
# ARQUIVO DE CONFIGURAÇÃO SECRETA
# ================================
if [ ! -f "$CONFIG_FILE" ]; then
  sudo mkdir -p "$CONFIG_PATH"
  sudo chown root:www-data "$CONFIG_PATH"
  sudo chmod 750 "$CONFIG_PATH"
  sudo tee "$CONFIG_FILE" > /dev/null <<EOF
[database]
name=$DB_NAME
user=$DB_USER
password=$DB_PASS

[django]
secret_key=$SECRET_KEY_DJANGO
EOF
  sudo chmod 640 "$CONFIG_FILE"
  sudo chown root:www-data "$CONFIG_FILE"
  echo "Arquivo de configuração criado."
else
  echo "Arquivo de configuração secreto já existe."
fi

# ================================
# REMOVE CONFIGURAÇÕES ANTIGAS NO settings.py
# ================================
sed -i "/SECRET_KEY =/d" "$SETTINGS"
# (descomente se precisar remover blocos antigos)
# sed -i "/DATABASES =/,/}/d" "$SETTINGS"
# sed -i "/STATIC_ROOT =/d" "$SETTINGS"
# sed -i "/LOGGING =/,/}/d" "$SETTINGS"

# ================================
# ADICIONA CONFIGURAÇÕES NO settings.py
# ================================
if ! grep -q "configparser" "$SETTINGS"; then
cat <<EOL >> "$SETTINGS"

import configparser
import os

config = configparser.ConfigParser(interpolation=None)
config.read('$CONFIG_FILE')

SECRET_KEY = config['django']['secret_key']

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': config['database']['name'],
        'USER': config['database']['user'],
        'PASSWORD': config['database']['password'],
        'HOST': 'localhost',
        'PORT': '3306',
    }
}

STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'ERROR',
            'class': 'logging.FileHandler',
            'filename': '$LOG_PATH/error.log',
            'formatter': 'verbose',
        },
        'app_debug': {
            'level': 'DEBUG',
            'class': 'logging.FileHandler',
            'filename': '$LOG_PATH/app_debug.log',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'ERROR',
            'propagate': True,
        },
        'app': {
            'handlers': ['app_debug'],
            'level': 'DEBUG',
            'propagate': False,
        },
    },
}
EOL
else
  echo "Configurações já adicionadas no settings.py"
fi

# ================================
# CRIA DIRETÓRIO STATICFILES
# ================================
mkdir -p "$SITE_DIR/staticfiles"

# ================================
# CRIA LOGS
# ================================
sudo mkdir -p "$LOG_PATH"
sudo touch "$LOG_PATH/error.log" "$LOG_PATH/app_debug.log"
sudo chown www-data:www-data "$LOG_PATH"/*.log
sudo chmod 640 "$LOG_PATH"/*.log

# ================================
# CONFIGURAÇÃO DO NGINX (BÁSICA) - sem SSL
# ================================
NGINX_CONF="/etc/nginx/sites-available/${DOMINIO}"
if [ ! -f "$NGINX_CONF" ]; then
  sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMINIO $DOMINIO_WWW;

    location / {
        proxy_pass http://unix:$SITE_DIR/gunicorn.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
  sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
  sudo rm -f /etc/nginx/sites-enabled/default
  sudo nginx -t && sudo systemctl reload nginx
  echo "Configuração Nginx criada e ativada."
else
  echo "Configuração Nginx já existe."
fi

# ================================
# INSTALAÇÃO DO CERTBOT (caso necessário)
# ================================
if ! command -v certbot >/dev/null 2>&1; then
    echo "Certbot não encontrado. Instalando Certbot com suporte NGINX..."
    sudo apt update && sudo apt install -y certbot python3-certbot-nginx
fi

# ================================
# GERAÇÃO DO CERTIFICADO SSL COM CERTBOT
# ================================
echo "Tentando emitir certificado SSL com Certbot para $DOMINIO e $DOMINIO_WWW..."
sudo certbot --nginx -d "$DOMINIO" -d "$DOMINIO_WWW" \
    --non-interactive --agree-tos -m "$NOME_SITE@$DOMINIO" || \
    echo "Certbot falhou (verifique domínio e DNS)."

CERT_PATH="/etc/letsencrypt/live/$DOMINIO/fullchain.pem"
if [ -f "$CERT_PATH" ]; then
    echo "Certificado SSL emitido com sucesso. Configurando NGINX com HTTPS..."

    sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMINIO $DOMINIO_WWW;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMINIO $DOMINIO_WWW;

    client_max_body_size 3M;

    location /static/ {
        alias $SITE_DIR/staticfiles/;
    }

    location /media/ {
        alias $SITE_DIR/media/;
    }

    location / {
        proxy_pass http://unix:$SITE_DIR/gunicorn.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
EOF

    sudo nginx -t && sudo systemctl reload nginx
else
    echo "Certificado SSL não encontrado. Pulando configuração HTTPS."
fi
# ================================
# GUNICORN SERVICE
# ================================
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [ ! -f "$SERVICE_FILE" ]; then
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=gunicorn daemon for $DOMINIO
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$SITE_DIR
ExecStart=$SITE_DIR/venv_${NOME_SITE}/bin/gunicorn --access-logfile - --workers 3 --bind unix:$SITE_DIR/gunicorn.sock --umask 007 $PROJETO.wsgi:application
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable "$SERVICE_NAME"
  sudo systemctl start "$SERVICE_NAME"
  echo "Serviço Gunicorn criado e iniciado."
else
  echo "Serviço Gunicorn já existe."
  sudo systemctl restart "$SERVICE_NAME"
fi

sudo chown -R www-data:www-data "$SITE_DIR"
sudo chmod 755 "$SITE_DIR"

# ================================
# CRIAÇÃO DO APP SE NÃO EXISTIR
# ================================
if [ ! -d "$SITE_DIR/$APP" ]; then
  cd "$SITE_DIR" || exit 1
  "$PYTHON" manage.py startapp "$APP"
  mkdir -p "$SITE_DIR/$APP"
  sed -i "/INSTALLED_APPS = \[/a\    '$APP'," "$SETTINGS"
  echo "App Django '$APP' criado e adicionado ao settings."
else
  echo "App Django '$APP' já existe."
fi

# ================================
# CONFIGURA URLs, VIEWS, TEMPLATES E STATIC
# ================================
# Só cria se arquivos não existirem (para evitar sobrescrever)
URLS_FILE="$SITE_DIR/$APP/urls.py"
if [ ! -f "$URLS_FILE" ]; then
tee "$URLS_FILE" > /dev/null <<EOF
from django.urls import path
from . import views

urlpatterns = [
    path('', views.home, name='home'),
]
EOF
  echo "Arquivo urls.py criado."
else
  echo "urls.py já existe."
fi

VIEWS_FILE="$SITE_DIR/$APP/views.py"
if [ ! -f "$VIEWS_FILE" ]; then
tee "$VIEWS_FILE" > /dev/null <<EOF
from django.shortcuts import render

def home(request):
    return render(request, '$APP/home.html')
EOF
  echo "Arquivo views.py criado."
else
  echo "views.py já existe."
fi

TEMPLATE_DIR="$SITE_DIR/$APP/templates/$APP"
if [ ! -d "$TEMPLATE_DIR" ]; then
  mkdir -p "$TEMPLATE_DIR"
fi

HOME_HTML="$TEMPLATE_DIR/home.html"
if [ ! -f "$HOME_HTML" ]; then
tee "$HOME_HTML" > /dev/null <<EOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8" />
    <title>Página Inicial</title>
    {% load static %}
    <link rel="stylesheet" href="{% static '$APP/css/home.css' %}">
</head>
<body>
    <h1 class="typewriter-line line1">Bem-vindo ao meu site!</h1>
    <h2 class="typewriter-line line2">Estamos construindo algo incrível...</h2>
</body>
</html>
EOF
  echo "Template HTML criado."
else
  echo "Template HTML já existe."
fi

STATIC_CSS_DIR="$SITE_DIR/$APP/static/$APP/css"
mkdir -p "$STATIC_CSS_DIR"

HOME_CSS="$STATIC_CSS_DIR/home.css"
if [ ! -f "$HOME_CSS" ]; then
tee "$HOME_CSS" > /dev/null <<EOF
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  height: 100vh;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 2rem;

  background: linear-gradient(-45deg, #2e3a59, #1e2a38, #3c4b64, #1c2c40);
  background-size: 400% 400%;
  animation: gradientMove 15s ease infinite;

  font-family: "Courier New", monospace;
  color: #ffffff;
}

.typewriter-line {
  overflow: hidden;
  border-right: 2px solid #ffffff;
  white-space: nowrap;
  width: 0;
  font-size: clamp(1rem, 4vw, 2rem);
}

.line1 {
  animation:
    typing1 3s steps(30, end) forwards,
    blink 0.8s step-end infinite;
}

.line2 {
  animation:
    typing2 2s steps(20, end) forwards,
    blink 0.8s step-end infinite;
  animation-delay: 3.5s;
}

@keyframes gradientMove {
  0%   { background-position: 0% 50%; }
  50%  { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

@keyframes typing1 {
  from { width: 0; }
  to   { width: 100%; }
}

@keyframes typing2 {
  from { width: 0; }
  to   { width: 100%; }
}

@keyframes blink {
  from, to { border-color: transparent; }
  50%      { border-color: #ffffff; }
}

@media (max-width: 400px) {
  body { padding: 1rem; }
  .typewriter-line { font-size: 1.1rem; }
}
EOF
  echo "CSS criado."
else
  echo "CSS já existe."
fi

# ================================
# CRIA JS VAZIO
# ================================
touch "$SITE_DIR/$APP/static/$APP/js/home.js"

# ================================
# COLETA ESTÁTICOS
# ================================
echo "Coletando arquivos estáticos..."
"$PYTHON" manage.py collectstatic --noinput

# ================================
# REINICIA O GUNICORN
# ================================
sudo systemctl restart "$SERVICE_NAME"

echo -e "\nInstalação do site '$NOME_SITE' concluída com sucesso em $DOMINIO"

# ================================
# LOGS DO GUNICORN (últimas 50 linhas)
# ================================
sudo journalctl -u "${SERVICE_NAME}.service" -n 50 --no-pager
