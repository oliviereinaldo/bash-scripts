#!/bin/bash

KEY_PATH="$HOME/.ssh/id_ed25519"

echo "Verificando se a chave SSH já existe..."

if [ -f "$KEY_PATH" ]; then
    echo "Chave SSH já existe em $KEY_PATH"
else
    echo "Gerando nova chave SSH..."
    read -p "Digite seu e-mail do GitHub: " GITHUB_EMAIL
    ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f "$KEY_PATH" -N ""
fi

echo "Iniciando o ssh-agent..."
eval "$(ssh-agent -s)"

echo "Adicionando a chave ao ssh-agent..."
ssh-add "$KEY_PATH"

echo
echo "Copie a chave pública abaixo e adicione em https://github.com/settings/keys"
echo "------------------------------------------------------------------"
cat "${KEY_PATH}.pub"
echo "------------------------------------------------------------------"
echo

read -p "Deseja testar a conexão SSH com o GitHub agora? (s/n): " testar
if [[ "$testar" =~ ^[Ss]$ ]]; then
    ssh -T git@github.com
fi
