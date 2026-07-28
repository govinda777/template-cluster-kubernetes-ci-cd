# Configuração Isolada do Git Credential Helper para AWS CodeCommit

Este documento explica como configurar o auxiliar de credenciais da AWS CLI (`aws codecommit credential-helper`) de forma **local**, garantindo que ele seja executado apenas dentro deste repositório (`template-cluster-kubernetes-ci-cd`) e não interfira em seus outros repositórios Git (como GitHub, GitLab, etc.).

---

## O Problema do Escopo Global (`--global`)

Quando configuramos o Git com `--global`, todas as requisições HTTP/HTTPS de qualquer repositório (incluindo GitHub) tentam usar o resolvedor de credenciais da AWS. Isso faz com que operações em outros serviços fiquem solicitando usuário/senha ou falhem na autenticação.

---

## Como Configurar Apenas para Este Repositório

### Passo 1: Remover as configurações globais da AWS
Se você já executou a configuração global anteriormente, remova-a para que ela pare de afetar os seus outros projetos:

```bash
git config --global --unset credential.helper
git config --global --unset credential.usehttppath
```

### Passo 2: Aplicar a configuração localmente neste repositório
Acesse a pasta raiz deste projeto (`template-cluster-kubernetes-ci-cd`) e execute os comandos com a flag `--local`:

```bash
cd /Users/govinda/projetos/template-cluster-kubernetes-ci-cd
git config --local credential.helper '!aws codecommit credential-helper $@'
git config --local credential.usehttppath true
```

Isso salvará a configuração diretamente no arquivo `.git/config` deste repositório, deixando o arquivo global `~/.gitconfig` livre de interferências.

---

## Verificando as Configurações

Para garantir que a alteração foi aplicada com sucesso:

1. **Dentro deste repositório**, execute:
   ```bash
   git config --get credential.helper
   ```
   *Retorno esperado:* `!aws codecommit credential-helper $@`

2. **Fora deste repositório** (ou em qualquer repositório do GitHub), execute o mesmo comando:
   ```bash
   git config --get credential.helper
   ```
   *Retorno esperado:* Vazio (ou o seu helper padrão do GitHub/macOS, como `osxkeychain`).
