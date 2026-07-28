# ADR 0004: Procedimento de Destruição Total e Reconstrução de Infraestrutura (Clean Slate)

## Status
Aprovado

## Contexto
Durante o desenvolvimento, testes e validação da plataforma de nuvem híbrida (AWS, GCP e Kubernetes Gateway API), é comum que recursos fiquem órfãos, que políticas do Kubernetes RBAC entrem em estado de colapso, ou que queiramos testar a resiliência e a corretude dos scripts de inicialização (bootstrap) do zero.

Para garantir que o fluxo de onboarding (`make config aws`) e os scripts de recuperação de acesso funcionem perfeitamente, precisamos de um mecanismo documentado para realizar a **destruição completa** de toda a infraestrutura provisionada e uma lista clara de quais configurações manuais devem ser refeitas após a limpeza.

---

## Decisão

Adotamos a estratégia de **"Clean Slate" (Tábula Rasa)**. Esta decisão define o processo padronizado para destruir e reconstruir de forma automatizada e segura todos os recursos gerenciados por nosso repositório IaC, garantindo um ambiente limpo para testes de ponta a ponta.

### 1. Comandos de Destruição Total (Clean Slate)

Toda a nossa infraestrutura é gerenciada declarativamente via **OpenTofu / Terraform** em três camadas principais:
1. **Ambiente de Desenvolvimento (`terraform/live/dev`):** Onde estão o cluster EKS, a VPC de desenvolvimento e os recursos do GCP.
2. **Ambiente de Produção (`terraform/live/prod`):** Onde residem os recursos correspondentes de produção.
3. **Módulo de Bootstrap (`terraform/bootstrap`):** Onde são configuradas as identidades OIDC, provedores OpenID Connect e Roles do GitHub Actions.

#### Roteiro de Execução de Destruição

Para limpar a conta por completo, execute os comandos abaixo na sequência exata. **Atenção: Este processo é irreversível e apagará todos os recursos das contas AWS/GCP correspondentes.**

```bash
# Unset de chaves de ambiente estáticas para garantir que estamos usando o perfil SSO correto
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# 1. Destruir os recursos do ambiente de Desenvolvimento (EKS, VPC, GKE)
echo "=== Destruindo Ambiente de Desenvolvimento ==="
cd terraform/live/dev
tofu init -upgrade
tofu destroy -auto-approve -var="enable_gke=false"
cd -

# 2. Destruir os recursos do ambiente de Produção (EKS, VPC)
echo "=== Destruindo Ambiente de Produção ==="
cd terraform/live/prod
tofu init -upgrade
tofu destroy -auto-approve
cd -

# 3. Destruir os recursos Globais de Bootstrap (OIDC Providers e IAM Roles do GitHub Actions)
echo "=== Destruindo Camada de Bootstrap OIDC e Roles ==="
cd terraform/bootstrap
tofu init -upgrade
# Substitua as variáveis com os valores que usou originalmente no bootstrap
tofu destroy -auto-approve -var="github_org_repo=<ORGANIZATION/REPO>"
cd -

echo "=== DESTRUIÇÃO TOTAL CONCLUÍDA COM SUCESSO ==="
```

---

## Consequências e Passos de Reconstrução

Uma vez que as contas estejam limpas, o processo de recriação necessita de algumas etapas manuais fundamentais para que a automação e o pipeline de CI/CD via GitHub Actions voltem a operar corretamente.

### Configurações Manuais que Devem ser Refeitas

#### 1. Autenticação Local do Desenvolvedor (AWS SSO / Identity Center)
O portal do AWS SSO deve estar ativo. Caso tenha perdido o login local, configure seu perfil local novamente:
```bash
# Executar a configuração interativa do SSO
aws configure sso
```

#### 2. Re-execução do Bootstrap OIDC e GitHub Secrets
Com as contas vazias, os segredos gravados no GitHub contendo os ARNs das Roles de CI/CD estarão apontando para recursos inexistentes. Execute o bootstrap local para recriar as identidades OIDC e atualizar automaticamente os segredos usando a GitHub CLI (`gh`):

```bash
# Este comando instala dependências ausentes, realiza o login no SSO,
# aplica o OpenTofu em terraform/bootstrap e configura os GitHub Secrets
make config aws
```
*Durante o prompt, responda "Y" para executar o bootstrap OIDC e configurar as Roles do GitHub.*

#### 3. Recriação Física do Backend de State S3 (Caso tenha sido apagado)
Os arquivos de estado (.tfstate) do OpenTofu dependem de um bucket S3 para armazenamento persistente. Se o bucket de State global foi destruído, você deve recriá-lo executando o utilitário de setup de backend:
```bash
# Executar script para provisionar o bucket S3 e a tabela de lock DynamoDB de State
bash scripts/setup-backend.sh
```

#### 4. Autorização Manual de Provedores OIDC Externos no GitHub (Se Aplicável)
Se sua organização do GitHub ou conta exige aprovações adicionais para integrações OIDC ou SSH Keys de deploy, configure-as novamente no painel de configurações do repositório em *Settings -> Actions -> General*.

#### 5. Re-configuração do Git Credential Helper (Escopo Local)
Após limpar as configurações locais ou trocar de ambiente, certifique-se de reativar o Credential Helper do CodeCommit apenas no escopo local para não conflitar com outros repositórios:
```bash
git config --local credential.helper '!aws codecommit credential-helper $@'
git config --local credential.UseHttpPath true
```

#### 6. Execução do Pipeline para Provisionar o Cluster
Com o bootstrap refeito e os novos segredos OIDC inseridos no GitHub, você pode disparar o pipeline do GitHub Actions simplesmente realizando um commit ou disparando um evento de *Workflow Dispatch* via GitHub Console para que o OpenTofu recrie automaticamente o cluster Kubernetes (EKS), a VPC e todos os recursos do zero de forma segura e limpa.
