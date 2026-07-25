# Configuração OIDC GitHub Actions para AWS

## Problema
A GitHub Actions está retornando o erro: `Not authorized to perform sts:AssumeRoleWithWebIdentity`

## Causa
O OIDC (OpenID Connect) não está habilitado nas configurações do repositório GitHub.

## Solução

### Passo 1: Verificar OIDC no Repositório GitHub

O OIDC já está habilitado no repositório. Verifique as configurações:

1. Acesse o repositório no GitHub: https://github.com/govinda777/template-cluster-kubernetes-ci-cd
2. Vá em **Settings** (Configurações)
3. No menu lateral, clique em **Actions** > **General**
4. Role até a seção **OIDC configuration**
5. Verifique o **Default subject claim prefix** que deve ser algo como:
   `repo:govinda777@498332/template-cluster-kubernetes-ci-cd@1311478241`

**Nota**: O GitHub usa o formato com `@` para repositórios criados/renomeados após 15 de julho de 2026 (immutable subject claims).

### Passo 2: Verificar Configuração OIDC

Após habilitar o OIDC, você pode verificar a configuração:

```bash
gh api repos/govinda777/template-cluster-kubernetes-ci-cd/actions/oidc/configure
```

### Passo 3: Verificar Secrets do GitHub

Os secrets já foram configurados automaticamente:
- `AWS_ROLE_TO_ASSUME_DEV`
- `AWS_ROLE_TO_ASSUME_PROD` 
- `AWS_ROLE_TO_ASSUME_TEST`
- `AWS_REGION`
- `AWS_REGION_PROD`

Você pode verificar com:
```bash
gh secret list --repo govinda777/template-cluster-kubernetes-ci-cd
```

### Passo 4: Verificar Configuração AWS

As roles IAM já foram criadas pelo bootstrap. Você pode verificar:

```bash
aws iam get-role --role-name github-actions-eks-dev-role --profile AdministratorAccess-533267373350
```

A trust policy deve incluir:
- OIDC Provider: `arn:aws:iam::533267373350:oidc-provider/token.actions.githubusercontent.com`
- Condition: `repo:govinda777/template-cluster-kubernetes-ci-cd:*`

## Testar a Pipeline

Após habilitar o OIDC, faça um novo commit ou push para testar a pipeline:

```bash
git commit --allow-empty -m "Test OIDC configuration"
git push origin main
```

## Troubleshooting

### Erro: "Not authorized to perform sts:AssumeRoleWithWebIdentity"
- Verifique se o OIDC está habilitado nas configurações do repositório
- Verifique se os secrets estão configurados corretamente
- Verifique se a trust policy da role IAM está correta

### Erro: "Could not assume role with OIDC"
- Verifique se o repositório GitHub está correto na trust policy
- Verifique se a branch está incluída na condition (ex: `repo:govinda777/template-cluster-kubernetes-ci-cd:*`)

## Documentação Adicional

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idc_oidc.html)
