#!/bin/bash

set -e

echo "Atualizando pacotes do sistema..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "Verificando e instalando pacotes essenciais..."
packages=(
    tree
    curl
    wget
    git
    htop
    net-tools
    unzip
    ufw
    software-properties-common
    ca-certificates
    lsb-release
)

for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" &> /dev/null; then
        echo "$pkg já está instalado."
    else
        echo "Instalando $pkg..."
        sudo apt-get install -y "$pkg"
    fi
done

echo "Versões dos pacotes instalados:"
tree --version | head -n 1
git --version
curl --version | head -n 1
htop --version
python3 --version
pip3 --version

echo "Configuração básica concluída!"
