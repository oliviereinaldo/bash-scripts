# Repositório de Scripts Automatizados

Este repositório contém scripts `.sh` automatizados para facilitar a criação de sites, monitoramento, manutenção e outras tarefas relacionadas à infraestrutura e deploy. O objetivo é simplificar processos repetitivos e garantir agilidade e padronização no ambiente.

---

# COMO CLONAR ESSE REPOSITÓRIO

Para começar a usar os scripts, primeiro você precisa ter o git e o GitHub CLI instalados e configurados. Após isso, clone este repositório na sua VPS ou ambiente local. Siga o passo a passo com os comandos abaixo no terminal:

# GUIA PARA INSTALAR GIT E GITHUB CLI NA VPS (Ubuntu/Debian)

1 - ATUALIZAR A LISTA DE PACOTES:

sudo apt update

2 - INSTALAR O GIT:

sudo apt install git -y
git --version  # para verificar se instalou corretamente

3 - CONFIGURAR USUÁRIO GIT (RECOMENDADO):

git config --global user.name "Seu Nome"
git config --global user.email "seu.email@exemplo.com"

4 - INSTALAR O GITHUB CLI (GH):

Verifique se o `gh` já está instalado:

gh --version

Se não estiver instalado, faça o seguinte:

4.1 - INSTALAR CURL (SE NECESSÁRIO):

sudo apt install curl -y

4.2 - ADICIONAR CHAVE GPG DO GITHUB CLI:

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

4.3 - ADICIONAR REPOSITÓRIO DO GITHUB CLI:

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update

4.4 - INSTALAR O GITHUB CLI:

sudo apt install gh -y
gh --version  # para verificar se instalou corretamente

5 -AUTENTICAR O GITHUB CLI:

gh auth login

Siga as instruções para autenticar seu usuário GitHub.

6 - CLONAR O REPOSITÓRIO COM O ARQUIVO .sh DESEJADO:

git clone https://github.com/oliviereinaldo/bash-scripts.git

7 - EXECUTAR O ARQUIVO .sh:

cd bash-scripts
chmod +x seu_arquivo.sh
./seu_arquivo.sh

---

OBSERVAÇÕES:

- Se preferir usar SSH para clonar, configure suas chaves SSH antes.
- Consulte a documentação oficial do Git: https://git-scm.com/doc
- Documentação do GitHub CLI: https://cli.github.com/manual/
