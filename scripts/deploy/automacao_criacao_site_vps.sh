#!/bin/bash

# ================================
# CONFIGURAÇÕES INICIAIS (ajuste com os valores corretos)
# ================================
NOME_SITE="meusite"
DOMINIO="meusite.com"
DOMINIO_WWW="www.meusite.com"
APP="principal"
PROJETO="core"
SERVICE_NAME="meusite"

SITE_DIR="/var/www/$NOME_SITE"
CONFIG_PATH="/etc/config_${NOME_SITE}"
CONFIG_FILE="${CONFIG_PATH}/${NOME_SITE}.config"
LOG_PATH="/var/log/${NOME_SITE}"

DB_NAME="meusite_db"
DB_USER="usr_meusite"
DB_PASS="senha_segura"
SECRET_KEY_DJANGO="sua_chave_django_aqui"

# ================================
# CRIA DIRETÓRIO DO PROJETO
# ================================
sudo mkdir -p "$SITE_DIR"
cd "$SITE_DIR" || exit 1

# ================================
# AMBIENTE VIRTUAL
# ================================
python3 -m venv "venv_${NOME_SITE}"

PIP="$SITE_DIR/venv_${NOME_SITE}/bin/pip"
PYTHON="$SITE_DIR/venv_${NOME_SITE}/bin/python"
DJANGO_ADMIN="$SITE_DIR/venv_${NOME_SITE}/bin/django-admin"

# ================================
# INSTALA DJANGO E DEPENDÊNCIAS
# ================================
"$PIP" install --upgrade pip
"$PIP" install django mysqlclient gunicorn

# ================================
# CRIA O PROJETO DJANGO
# ================================
"$DJANGO_ADMIN" startproject "$PROJETO" .

# ================================
# AJUSTA DEBUG E ALLOWED_HOSTS NO settings.py
# ================================
SETTINGS="$SITE_DIR/$PROJETO/settings.py"

sed -i "s/^DEBUG = True/DEBUG = False/" "$SETTINGS"

if ! grep -q "^ALLOWED_HOSTS" "$SETTINGS"; then
    echo -e "\nALLOWED_HOSTS = ['$DOMINIO', '$DOMINIO_WWW']" >> "$SETTINGS"
else
    sed -i "s/^ALLOWED_HOSTS.*/ALLOWED_HOSTS = ['$DOMINIO', '$DOMINIO_WWW']/" "$SETTINGS"
fi

# ================================
# ARQUIVO DE CONFIGURAÇÃO SECRETA
# ================================
sudo mkdir -p "$CONFIG_PATH"
sudo chown root:www-data "$CONFIG_PATH"
sudo chmod 750 "$CONFIG_PATH"  # dono root rwx, grupo www-data r-x

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

# ================================
# REMOVE CONFIGURAÇÕES ANTIGAS NO settings.py
# ================================
sed -i "/SECRET_KEY =/d" "$SETTINGS"
# sed -i "/DATABASES =/,/}/d" "$SETTINGS"
# sed -i "/STATIC_ROOT =/d" "$SETTINGS"
# sed -i "/LOGGING =/,/}/d" "$SETTINGS"

# ================================
# ADICIONA CONFIGURAÇÕES NO settings.py
# ================================
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

# ================================
# REMOÇÃO DE CARACTER
# ================================
# sed -i '/# Database/{n;/^\s*}\s*$/d;}' "$SETTINGS"

# ================================
# CRIA DIRETÓRIO STATICFILES (para collectstatic)
# ================================
mkdir -p "$SITE_DIR/staticfiles"

# ================================
# LOGS
# ================================
sudo mkdir -p "$LOG_PATH"
sudo touch "$LOG_PATH/error.log" "$LOG_PATH/app_debug.log"
sudo chown www-data:www-data "$LOG_PATH"/*.log
sudo chmod 640 "$LOG_PATH"/*.log

# ================================
# CONFIGURAÇÃO TEMPORÁRIA DO NGINX (HTTP somente, sem SSL)
# ================================
NGINX_CONF="/etc/nginx/sites-available/${DOMINIO}"
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

# ================================
# GERAÇÃO DO CERTIFICADO SSL COM CERTBOT
# ================================
sudo certbot --nginx -d "$DOMINIO" -d "$DOMINIO_WWW" --non-interactive --agree-tos -m ocsr@ocsr.com || echo "Certbot falhou (verifique domínio e DNS)."
ATIVAR
CERT_PATH="/etc/letsencrypt/live/$DOMINIO/fullchain.pem"

if [ ! -f "$CERT_PATH" ]; then
    echo "Emitindo certificado SSL com Certbot para $DOMINIO e $DOMINIO_WWW..."
    sudo certbot --nginx -d "$DOMINIO" -d "$DOMINIO_WWW" \
        --non-interactive --agree-tos -m ocsr@ocsr.com || \
        echo "Certbot falhou (verifique domínio e DNS ou aguarde o limite da Let's Encrypt expirar)."
else
    echo "Certificado SSL já existe. Pulando emissão com Certbot."
fi

# ================================
# CONFIGURAÇÃO DEFINITIVA DO NGINX COM SSL
# ================================
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

# ================================
# GUNICORN SERVICE
# ================================
sudo chown -R www-data:www-data "$SITE_DIR"
sudo chmod 755 "$SITE_DIR"

sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" > /dev/null <<EOF
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

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# Ajusta o dono do socket para www-data
sudo chown www-data:www-data "$SITE_DIR/gunicorn.sock" || echo "Socket ainda não criado, aguardando o gunicorn iniciar"

# Verifica status
sudo systemctl status "$SERVICE_NAME" --no-pager -n 20

# ================================
# CRIAÇÃO DO APP
# ================================
cd "$SITE_DIR" || exit 1

"$PYTHON" manage.py startapp "$APP"

# ================================
# CRIA DIRETÓRIO DO APP ANTES DE CRIAR ARQUIVOS
# ================================
mkdir -p "$SITE_DIR/$APP"

# ================================
# ADICIONA APP NO INSTALLED_APPS
# ================================
sed -i "/INSTALLED_APPS = \[/a\    '$APP'," "$SETTINGS"

# ================================
# CONFIGURA URLs DO APP
# ================================
tee "$SITE_DIR/$APP/urls.py" > /dev/null <<EOF
from django.urls import path
from . import views

urlpatterns = [
    path('', views.home, name='home'),
]
EOF

# ================================
# CONFIGURA VIEWs DO APP
# ================================
tee "$SITE_DIR/$APP/views.py" > /dev/null <<EOF
from django.shortcuts import render

def home(request):
    return render(request, '$APP/home.html')
EOF

# ================================
# CONFIGURA URLs DO PROJETO
# ================================
# # Adiciona import de include em urls.py do projeto se não existir
# if ! grep -q "from django.urls import include" "$SITE_DIR/$PROJETO/urls.py"; then
#     sed -i "1ifrom django.urls import include" "$SITE_DIR/$PROJETO/urls.py"
# fi

# # Adiciona path do app no urlpatterns se não existir
# if ! grep -q "path('', include('$APP.urls'))" "$SITE_DIR/$PROJETO/urls.py"; then
#     sed -i "/urlpatterns = \[/a\    path('', include('$APP.urls'))," "$SITE_DIR/$PROJETO/urls.py"
# fi

URLS_FILE="$SITE_DIR/$PROJETO/urls.py"

# Adiciona 'include' ao import de path se ele ainda não estiver na mesma linha
if grep -q "^from django.urls import path" "$URLS_FILE" && ! grep -q "^from django.urls import path, include" "$URLS_FILE"; then
    sed -i "s/^from django.urls import path/from django.urls import path, include/" "$URLS_FILE"
fi

# Caso nenhuma linha de import exista (situação rara), insere no topo
if ! grep -q "^from django.urls import " "$URLS_FILE"; then
    sed -i "1ifrom django.urls import path, include" "$URLS_FILE"
fi

# Adiciona path do app se ainda não estiver
if ! grep -q "include('$APP.urls')" "$URLS_FILE"; then
    sed -i "/urlpatterns = \[/a\    path('', include('$APP.urls'))," "$URLS_FILE"
fi

# ================================
# CRIA DIRETÓRIOS DE TEMPLATES E STATIC
# ================================
mkdir -p "$SITE_DIR/$APP/templates/$APP"
mkdir -p "$SITE_DIR/$APP/static/$APP/css" "$SITE_DIR/$APP/static/$APP/js" "$SITE_DIR/$APP/static/$APP/images" "$SITE_DIR/$APP/static/$APP/videos"

# ================================
# CRIA TEMPLATE HTML COM ANIMAÇÃO
# ================================
tee "$SITE_DIR/$APP/templates/$APP/home.html" > /dev/null <<EOF
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

# ================================
# CRIA CSS COM ANIMAÇÃO
# ================================
tee "$SITE_DIR/$APP/static/$APP/css/home.css" > /dev/null <<EOF
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

# ================================
# CRIA JS VAZIO (caso queira usar depois)
# ================================
touch "$SITE_DIR/$APP/static/$APP/js/home.js"

# ================================
# COLETA ESTÁTICOS E REINICIA GUNICORN
# ================================
"$PYTHON" manage.py collectstatic --noinput
sudo systemctl restart "$SERVICE_NAME"

echo -e "\nInstalação do site '$NOME_SITE' concluída com sucesso em $DOMINIO"

# ================================
# VERIFICAÇÃO FINAL DO GUNICORN
# ================================
sudo journalctl -u "${SERVICE_NAME}.service" -n 50 --no-pager
