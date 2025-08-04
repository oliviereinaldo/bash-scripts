#!/bin/bash
set -e

echo "Instalando UFW (se já estiver instalado, será ignorado)..."
sudo apt update
sudo apt install -y ufw

echo "Configurando política padrão do firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "Liberando portas essenciais..."
sudo ufw allow 22      # SSH
sudo ufw allow 80      # HTTP
sudo ufw allow 443     # HTTPS

echo "Ativando o UFW..."
sudo ufw --force enable

echo "Regras ativas atualmente:"
sudo ufw status verbose

echo "Configuração do firewall concluída com sucesso."
