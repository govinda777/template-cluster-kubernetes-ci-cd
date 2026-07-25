# Integração de Autenticação Segura: Git & AWS (AWS CLI Credential Helper & SSO)

Este documento descreve detalhadamente a arquitetura, o fluxo de execução, a configuração e o monitoramento da autenticação entre o cliente Git local e os repositórios hospedados na AWS (como o Amazon CodeCommit).

Esta solução elimina a necessidade de chaves de acesso estáticas ou senhas de longa duração, integrando diretamente as identidades do **AWS IAM** e **AWS Single Sign-On (SSO)** ao mecanismo de transporte de rede do Git por meio de credenciais efêmeras assinadas via **AWS Security Token Service (STS)** e **Signature Version 4 (SigV4)**.

---

## 1. Visão Geral e Arquitetura

O Git nativo utiliza abordagens tradicionais para autenticação em repositórios remotos, como HTTPS (com senhas estáticas ou *Personal Access Tokens*) e SSH (com chaves públicas e privadas). Por sua vez, o ecossistema AWS opera com identidades IAM e autorização baseada em assinaturas criptográficas de requisições.

Para conectar de forma transparente e segura o fluxo de desenvolvimento local aos serviços da AWS, este projeto adota o **AWS CLI Credential Helper** (`aws codecommit credential-helper`). Trata-se de um utilitário de sistema configurado no Git que intercepta as chamadas de rede HTTP/HTTPS destinadas à AWS e injeta dinamicamente credenciais de curtíssimo prazo geradas pelo AWS CLI.

### Fluxo de Autenticação Dinâmica (`git push` / `git pull`)

Toda vez que uma operação de rede do Git é disparada para o domínio da AWS, o fluxo abaixo ocorre em segundo plano de forma transparente para o desenvolvedor:

```
+----------------+          1. git push          +-------------------+
|   Git Client   | ----------------------------> |  AWS CodeCommit   |
+----------------+                               +-------------------+
        |                                                  ^
        | 2. Pede credenciais                              |
        v                                                  |
+------------------------------------+                     | 5. Requisição HTTP
| aws codecommit credential-helper   |                     |    assinada com SigV4
+------------------------------------+                     |
        |                                                  |
        | 3. Lê credenciais ativas do IAM/SSO              |
        v                                                  |
+------------------------------------+                     |
| AWS CLI / STS (~/.aws/credentials) | --------------------+
+------------------------------------+ 4. Gera credencial temporária
```

1. **Disparo do comando:** O desenvolvedor executa `git push origin main` ou `git pull`.
2. **Interceptação:** O Git consulta suas configurações (`.git/config` ou `~/.gitconfig`) e identifica que o domínio do repositório requer o uso do `credential.helper` configurado (`!aws codecommit credential-helper $@`).
3. **Resolução de Identidade:** O assistente de credenciais aciona a AWS CLI, que busca o perfil ativo (`AWS_PROFILE`) e as credenciais correspondentes no repositório local de credenciais ou no cache de sessão do SSO (`~/.aws/sso/cache/`).
4. **Geração de Credenciais Temporárias (STS):** A AWS CLI solicita ou calcula uma assinatura criptográfica de curta duração baseada em credenciais efêmeras fornecidas pelo **AWS STS**.
5. **Envio e Liberação:** O assistente de credenciais converte essa assinatura em um par temporário de usuário/senha HTTP e devolve para o cliente Git. Este, por sua vez, realiza a requisição HTTP assinada via **SigV4** para liberar o acesso ao repositório CodeCommit.

---

## 2. Geração de Credenciais Temporárias (AWS STS & SigV4)

Quando o **AWS CLI Credential Helper** atua, as chaves mestras ou de longa duração do desenvolvedor **nunca** são transmitidas. Em vez disso, a AWS baseia toda a sua segurança no princípio de privilégio mínimo assistido por credenciais efêmeras obtidas através do **AWS Security Token Service (STS)**.

### O que compõe uma credencial temporária?

As credenciais geradas pelo STS diferem das chaves permanentes (que começam tipicamente com o prefixo `AKIA`). Chaves temporárias possuem quatro componentes vitais:

1. **`AWS_ACCESS_KEY_ID`**: O identificador público temporário da chave de acesso. No caso de credenciais temporárias, ele se inicia obrigatoriamente com o prefixo **`ASIA`**.
2. **`AWS_SECRET_ACCESS_KEY`**: A chave privada associada que será utilizada para assinar as mensagens HTTP. Ela serve exclusivamente como parâmetro matemático local e nunca trafega pela rede.
3. **`AWS_SESSION_TOKEN`**: Um token criptográfico de grande extensão. Ele deve ser anexado a todas as chamadas de API da AWS que usam as credenciais temporárias correspondentes, funcionando como prova da validade da sessão no serviço STS.
4. **Timestamp de Expiração (TTL)**: Um limite de tempo estrito (configurado entre 15 minutos e 12 horas). Expirado este prazo, o token é invalidado imediatamente na AWS e uma nova requisição ao STS torna-se necessária.

### O papel do Algoritmo Signature Version 4 (SigV4)

O protocolo HTTPS do Git exige autenticação básica, mas para segurança avançada, a AWS utiliza a especificação **SigV4** para assinar cada requisição HTTP de forma única. O processo funciona da seguinte forma:

1. O Git invoca o assistente de credenciais fornecendo o contexto da requisição (URI do repositório, data atualizada, payload/conteúdo, se aplicável).
2. A AWS CLI utiliza a `AWS_SECRET_ACCESS_KEY` (temporária `ASIA`) para computar uma assinatura criptográfica baseada em um *hash* HMAC-SHA256 de via única.
3. Essa assinatura e o `AWS_SESSION_TOKEN` são mapeados em um cabeçalho HTTP padrão:
   ```http
   Authorization: AWS4-HMAC-SHA256 Credential=ASIAXXXXXXXXXXXXXXXX/20260725/us-east-1/codecommit/aws4_request, SignedHeaders=host;x-amz-date, Signature=f3a8b417c9d1...
   ```
4. O servidor CodeCommit descriptografa o cabeçalho e recalcula localmente o *hash*. Se os valores coincidirem e a assinatura não estiver expirada, a transação Git é autorizada.

Desta forma, mesmo que uma requisição HTTP seja interceptada, ela é válida apenas para aquele segundo exato de execução e para aquela URI específica, impossibilitando ataques de repetição.

---

## 3. Pré-requisitos da Máquina Local

Para que as ferramentas de automação e autenticação funcionem perfeitamente, o ambiente do desenvolvedor deve possuir os seguintes componentes instalados e configurados:

### Softwares Necessários

* **Git (v2.20 ou superior):** Cliente de controle de versão.
* **AWS CLI (v2):** Interface de linha de comando da AWS instalada e disponível no `PATH`.
* **GitHub CLI (`gh`):** Necessário para a automação de upload de segredos do bootstrap OIDC.
* **OpenTofu / Terraform:** Para provisionamento de infraestrutura local e IAM Roles.
* **GNU Make:** Para interpretar e executar os atalhos do `Makefile`.

### Configuração Inicial do Perfil AWS (AWS SSO)

Recomenda-se fortemente a utilização do **AWS Single Sign-On (SSO)** para controle de acesso federado.

Para configurar o seu portal SSO localmente na AWS CLI, execute o comando:
```bash
aws configure sso
```
Siga as instruções fornecidas pelo assistente técnico:
* **SSO start URL:** `https://<sua-organizacao>.awsapps.com/start`
* **SSO Region:** A região onde o AWS IAM Identity Center está provisionado (ex: `us-east-1`).
* **Região padrão:** A região principal do seu projeto (ex: `us-east-1`).
* **Formato de saída padrão:** `json`
* **CLI profile name:** Escolha um nome descritivo (ex: `my-dev-profile`).

Para realizar login nas sessões subsequentes sem reconfigurar:
```bash
aws sso login --profile my-dev-profile
```

---

## 4. O Comando `make config-aws`

Este repositório possui uma interface baseada em `Makefile` projetada para acelerar o onboarding do desenvolvedor e automatizar o setup do ambiente.

### Objetivo do comando

O alvo `make config-aws` (ou alternativamente utilizando a sintaxe de espaço `make config aws`) invoca o script inteligente localizado em `scripts/config-aws.sh`. Esse script executa as seguintes tarefas:

1. **Auto-instalação de Dependências:** Detecta o sistema operacional (Linux ou macOS) e instala automaticamente o Git, GitHub CLI (`gh`), OpenTofu (`tofu`) e AWS CLI se não estiverem presentes no sistema.
2. **Validação de Identidade e Sessão Ativa:** Verifica se o arquivo local `.aws_profile_env` possui um perfil e região configurados. Ele executa `aws sts get-caller-identity` para atestar a validade da sessão.
3. **Login SSO Automatizado:** Se a sessão estiver expirada, ele engaja de forma transparente o comando de login (`aws sso login`) para reativar as credenciais.
4. **Bootstrap OIDC (Opcional):** Permite inicializar e aplicar as regras de IAM Role de forma local via OpenTofu para configurar a integração de CI/CD (GitHub Actions com login keyless via AWS OIDC), salvando os ARNs resultantes diretamente nos GitHub Secrets do repositório através do `gh secret set`.
5. **Configuração do Git Credential Helper:** Aplica as configurações do Git necessárias para usar a AWS CLI para autenticação do CodeCommit.

### Modificações Realizadas no Ambiente Local

O comando modifica arquivos de configuração vitais do desenvolvedor para garantir a persistência das sessões:

#### A. Arquivo `.aws_profile_env` (Ignorado no Git)
O script persiste o perfil ativo e a região neste arquivo, que é incluído automaticamente pelo `Makefile`:
```bash
AWS_PROFILE=my-dev-profile
AWS_REGION=us-east-1
```

#### B. Configuração do Git local/global (`.git/config` ou `~/.gitconfig`)
O script executa internamente os comandos:
```bash
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```

* **`credential.helper '!aws codecommit credential-helper $@'`**: Diz ao Git para delegar a resolução de credenciais para o utilitário `aws codecommit credential-helper`. O caractere de exclamação (`!`) indica ao Git que ele deve invocar o comando como um script externo do sistema (via shell) em vez de procurar um binário nativo interno.
* **`credential.UseHttpPath true`**: Instrui o Git a enviar o caminho completo do repositório (ex: `https://git-codecommit.us-east-1.amazonaws.com/v1/repos/meu-repo`) ao invés de apenas o domínio principal (`https://git-codecommit.us-east-1.amazonaws.com`). Isto é crucial porque a AWS utiliza o caminho completo do repositório HTTP para identificar políticas de acesso específicas vinculadas ao IAM.

> **Dica de Escopo:** Por padrão, o script configura globalmente (`--global`). Caso você possua outros servidores Git privados e prefira isolar esta configuração apenas para este repositório de trabalho, altere para `--local` dentro da pasta do projeto:
> ```bash
> git config --local credential.helper '!aws codecommit credential-helper $@'
> git config --local credential.UseHttpPath true
> ```

---

## 5. Guia Passo a Passo para Novos Desenvolvedores

Siga este roteiro prático para preparar seu computador local e realizar sua primeira operação no repositório AWS:

### Passo 1: Clonar o Repositório do Projeto
Clone o repositório utilizando a sua URL HTTP correspondente da AWS:
```bash
git clone https://git-codecommit.us-east-1.amazonaws.com/v1/repos/template-cluster-kubernetes-ci-cd
cd template-cluster-kubernetes-ci-cd
```

### Passo 2: Executar o Comando de Configuração Automática
Rode o comando de bootstrapping:
```bash
make config aws
```
O script fará a varredura das dependências no seu sistema. Se a AWS CLI ou o OpenTofu não estiverem presentes, ele iniciará a instalação interativa.

### Passo 3: Escolha o Perfil e Autentique-se via SSO
* Caso não tenha um perfil SSO ativo na máquina, o script oferecerá a opção para rodar `aws configure sso`.
* Caso possua um perfil existente, o script irá listá-lo para seleção. Escolha o perfil e digite as suas credenciais no navegador que se abrirá automaticamente.

### Passo 4: Validar a Identidade
O script retornará a identidade ativa em seu console:
```text
[OK] Sessão AWS SSO validada com sucesso!
  - Conta (Account ID): 123456789012
  - Usuário (UserId): AROAXXXXXXXXXXXXXXXXX:user-sso
  - ARN: arn:aws:sts::123456789012:assumed-role/AWSReservedSSO_Dev_xxx/user-sso
```

### Passo 5: Testar Conexão com o Repositório Git da AWS
Com o Credential Helper devidamente configurado, tente realizar uma leitura simples:
```bash
git fetch origin
```
Se o comando for executado silenciosamente sem pedir usuário/senha ou sem disparar falhas de permissão, a autenticação dinâmica está operando corretamente!

---

## 6. Monitoramento e Auditoria de Sessões na AWS

Por utilizarmos tokens dinâmicos que expiram rapidamente, não há uma listagem de "sessões persistentes abertas" em servidores web. A governança e a auditoria dessas atividades de autenticação baseiam-se em **análise de telemetria de chamadas de API** e **inspeção de caches locais**.

### A. Monitoramento via AWS CloudTrail (Console Web)

O **AWS CloudTrail** rastreia de forma centralizada todas as chamadas efetuadas às APIs da AWS. Toda ação do Git interceptada pelo Credential Helper que interage com o CodeCommit gera eventos de auditoria.

#### Como pesquisar eventos no CloudTrail:
1. Acesse o console de gerenciamento da AWS e vá até o serviço **CloudTrail**.
2. No menu lateral esquerdo, clique em **Event history** (Histórico de eventos).
3. Utilize os filtros de pesquisa:
   * **Event name:** Selecione `GetCallerIdentity`, `AssumeRole`, `GitPush` ou `GitPull`.
   * **Event source:** Selecione `codecommit.amazonaws.com` ou `sts.amazonaws.com`.

#### Exemplo de Registro de Evento CloudTrail (Formato JSON):
```json
{
  "eventTime": "2026-07-25T13:45:00Z",
  "eventName": "GitPush",
  "eventSource": "codecommit.amazonaws.com",
  "userIdentity": {
    "type": "AssumedRole",
    "principalId": "AROAXXXXXXXXXXXXXXXXX:nome-do-usuario",
    "arn": "arn:aws:sts::123456789012:assumed-role/DevRole/nome-do-usuario",
    "accountId": "123456789012",
    "accessKeyId": "ASIAXXXXXXXXXXXXXXXX"
  },
  "sourceIPAddress": "203.0.113.195",
  "userAgent": "git/2.43.0 (aws-cli/2.15.0 python/3.11.0)"
}
```

* **Nota de Análise DevOps:** O campo `accessKeyId` começando com o prefixo **`ASIA`** confirma que o desenvolvedor acessou o repositório remotamente utilizando credenciais temporárias do STS geradas de forma dinâmica. O campo `arn` aponta exatamente para o perfil e identidade federada que disparou a ação.

---

### B. Inspecionando a Sessão Localmente

Caso queira avaliar os detalhes da sessão na sua própria máquina de desenvolvimento antes de subir alterações:

#### 1. Validando a Identidade Ativa
Para atestar qual conta, perfil e ARN de Role estão carregados na sua sessão atual do terminal, execute:
```bash
aws sts get-caller-identity
```

#### 2. Inspecionando o cache físico de sessões
A AWS CLI v2 armazena os metadados e os tokens JWT temporários de SSO localmente em formato JSON estruturado.
* **Caminho padrão no Linux/macOS:** `~/.aws/cli/cache/` ou `~/.aws/sso/cache/`
* **Caminho padrão no Windows:** `%USERPROFILE%\.aws\cli\cache\`

Você pode abrir estes arquivos JSON para verificar informações de auditoria local, como o campo `ExpiresAt` (data e hora exata de expiração do token local em formato ISO-8601).

---

### C. Monitoramento Avançado com CloudWatch Logs Insights

Em infraestruturas corporativas robustas, os rastros de auditoria do CloudTrail são ingeridos no **Amazon CloudWatch Logs**. Você pode utilizar consultas estruturadas para monitorar a frequência de deploys ou identificar potenciais acessos anômalos.

#### Consulta recomendada para listar os últimos 50 disparos de `GitPush` agregados por ARN de sessão nas últimas 24 horas:
```sql
fields @timestamp, userIdentity.arn, userAgent, sourceIPAddress
| filter eventSource = 'codecommit.amazonaws.com' and eventName = 'GitPush'
| sort @timestamp desc
| limit 50
```

---

### D. Revogação de Emergência de Sessões Temporárias

Se um token de sessão ou chave temporária (`ASIA`) for vazada acidentalmente ou se o computador de um colaborador for roubado, não há uma "chave estática" para excluir. A neutralização do vazamento deve ocorrer pela **revogação imediata da Role**.

1. Acesse o painel do **AWS IAM Console** e clique em **Roles** (Funções).
2. Selecione a Role correspondente utilizada pelo desenvolvedor comprometido (ex: `DevRole`).
3. Clique na aba **Revoke sessions** (Revogar sessões).
4. Clique no botão **Revoke active sessions** (Revogar sessões ativas).
5. A AWS irá adicionar automaticamente uma política inline restritiva à Role chamada `AWSRevokeOlderSessions`. Ela se parecerá com o exemplo abaixo:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Deny",
         "Action": ["*"],
         "Resource": ["*"],
         "Condition": {
           "DateLessThan": {
             "aws:TokenIssueTime": "2026-07-25T14:00:00.000Z"
           }
         }
       }
     ]
   }
   ```
Esta regra nega terminantemente qualquer requisição feita com chaves geradas antes do carimbo de data/hora da revogação, inutilizando instantaneamente o token vazado sem prejudicar a criação de novas sessões autorizadas após esse horário.

---

## 7. Troubleshooting & Erros Comuns

### Erro 1: `403 Access Denied` ou `Permission denied` ao rodar comandos Git
* **Causa:** O perfil AWS configurado no terminal está sem sessão válida, ou as variáveis de ambiente estáticas (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) estão carregadas com credenciais antigas ou de outra conta, impedindo a AWS CLI de usar o SSO.
* **Resolução:**
  1. Limpe variáveis conflitantes no seu shell:
     ```bash
     unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
     ```
  2. Execute `make config-aws` e selecione a opção de login para restabelecer a integridade da sessão do terminal.

### Erro 2: `credential-aws is not a git command`
* **Causa:** O Git tentou buscar o comando `credential-aws` no PATH por conta de uma sintaxe incorreta de configuração no arquivo `.git/config`.
* **Resolução:** Certifique-se de que a configuração do Git possui a exclamação (`!`) antecedendo o comando da AWS, o que instrui o Git a delegar a chamada para o interpretador externo:
  ```bash
  git config --global credential.helper '!aws codecommit credential-helper $@'
  ```

### Erro 3: Sessão expirada do AWS SSO / STS
* **Causa:** O tempo máximo de vida do token de acesso expirou.
* **Resolução:** Rode o comando rápido de login correspondente ao seu perfil:
  ```bash
  aws sso login --profile <nome-do-perfil>
  ```

---

## 8. Boas Práticas de Segurança

Para manter a segurança e a integridade da sua infraestrutura e do código do repositório, adote as seguintes práticas operacionais:

1. **Evite chaves estáticas (AKIA):** Nunca crie ou salve chaves de longa duração no arquivo `~/.aws/credentials`. Priorize sempre a federação de identidades via AWS SSO / IAM Identity Center.
2. **Defina tempos de vida reduzidos (TTL):** Configure a duração máxima da sessão de suas IAM Roles SSO para o menor período compatível com a sua jornada de trabalho (ex: 2 a 4 horas). Isso minimiza a janela de exposição de tokens temporários.
3. **Mantenha o arquivo `.gitignore` atualizado:** Nunca versione arquivos como `.aws_profile_env`, chaves `.pem`, arquivos `.tfstate` ou pastas de caches locais. Verifique constantemente o arquivo `.gitignore` na raiz do projeto.
4. **Isolamento de Escopo do Git Helper:** Se você interage com múltiplos clientes e diferentes repositórios Git corporativos na mesma máquina, configure o Credential Helper localmente (`--local`) no repositório de trabalho específico ao invés de ativá-lo de forma global.
