#!/bin/bash

# ------------------------------------------------------------------------------
# Script de configuração inicial de chave SSH com GitHub
# 1. Gera a chave SSH (se necessário)
# 2. Adiciona ao ssh-agent
# 3. Permite envio automático da chave para o GitHub via API (usando PAT)
# ------------------------------------------------------------------------------

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

# Copia a chave pública para uma variável
SSH_KEY_CONTENT=$(cat "${KEY_PATH}.pub")

echo
read -p "Deseja adicionar automaticamente a chave SSH ao GitHub via API? (s/n): " adicionar

if [[ "$adicionar" =~ ^[Ss]$ ]]; then

    echo
    echo "Para usar a API do GitHub, é necessário um token de acesso pessoal (PAT)."
    echo "Siga os passos abaixo para gerar o seu:"
    echo
    echo "1. Acesse: https://github.com/settings/tokens"
    echo "2. Clique em: Generate new token"
    echo "3. Marque a permissão: admin:public_key"
    echo "4. Copie e guarde o token com segurança"
    echo

    read -p "Cole aqui seu token de acesso pessoal (PAT): " GITHUB_TOKEN
    read -p "Digite um nome para a chave (ex: Chave da VM): " KEY_TITLE

    echo "Enviando chave para o GitHub..."

    RESPONSE=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        https://api.github.com/user/keys \
        -d "{\"title\":\"$KEY_TITLE\",\"key\":\"$SSH_KEY_CONTENT\"}")

    if echo "$RESPONSE" | grep -q "\"id\":"; then
        echo "Chave SSH adicionada com sucesso ao GitHub."
    else
        echo "Falha ao adicionar a chave. Detalhes:"
        echo "$RESPONSE"
    fi
else
    echo
    echo "Copie a chave pública abaixo e adicione manualmente em https://github.com/settings/keys"
    echo "------------------------------------------------------------------"
    echo "$SSH_KEY_CONTENT"
    echo "------------------------------------------------------------------"
fi

echo
read -p "Deseja testar a conexão com o GitHub agora? (s/n): " testar
if [[ "$testar" =~ ^[Ss]$ ]]; then
    echo "Testando conexão com o GitHub..."
    ssh -T git@github.com
fi
