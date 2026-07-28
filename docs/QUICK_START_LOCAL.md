# Guia de Início Rápido - Desenvolvimento e Testes Locais (ADR 0006)

Este guia ensina como iniciar e validar rapidamente o ecossistema de infraestrutura de microsserviços e GitOps localmente no seu computador, sem depender de recursos de nuvem pública (AWS/GCP), utilizando **Kind (Kubernetes in Docker)**.

---

## 🛠️ Pré-requisitos

Para rodar o ambiente local, você precisa ter instalado:
1. **Docker Desktop** (rodando)
2. **Kind** (`brew install kind`)
3. **Kubectl** (`brew install kubectl`)
4. **Kustomize** (`brew install kustomize`)

---

## 🚀 Passo a Passo

### 1. Configurar os Git Hooks (Automatização do DoD)
Para ativar a execução automática dos testes unitários no `commit` e testes BDD no `push`, execute:
```bash
bash .agents/skills/local-dev-and-testing/scripts/install-hooks.sh
```

### 2. Iniciar o Cluster Kubernetes Local
Para criar o cluster Kind, configurar as portas locais (80/443), e instalar os CRDs do Gateway API, Envoy Gateway e o ArgoCD, execute:
```bash
bash .agents/skills/local-dev-and-testing/scripts/setup-local-env.sh
```

### 3. Executar os Testes Unitários e Análise Estática (Pre-commit)
Para rodar a verificação de linting do Terraform/OpenTofu, validação de sintaxe YAML e políticas de segurança OPA (Open Policy Agent) localmente:
```bash
bash .agents/skills/local-dev-and-testing/scripts/run-unit-tests.sh
```

### 4. Executar os Testes BDD / Integração Locais (Pre-push)
Para realizar o deploy temporário da aplicação no seu cluster local, testar a integridade dos Pods e validar a comunicação HTTP simulando a chamada real:
```bash
bash .agents/skills/local-dev-and-testing/scripts/run-bdd-tests.sh
```

### 5. Destruir o Ambiente Local e Liberar Recursos
Quando terminar o desenvolvimento, você pode apagar o cluster Kind local e limpar os volumes Docker gerados executando:
```bash
bash .agents/skills/local-dev-and-testing/scripts/destroy-local-env.sh
```

---

## 💡 Como funciona o fluxo de trabalho (DoD)?

* **Ao fazer `git commit`**: O Git executa a suíte de testes unitários ([run-unit-tests.sh](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/.agents/skills/local-dev-and-testing/scripts/run-unit-tests.sh)). Se houver erros de formatação ou de políticas Rego/OPA, o commit é abortado para correção.
* **Ao fazer `git push`**: O Git valida se o seu cluster local está ativo e executa os testes de BDD/Integração ([run-bdd-tests.sh](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/.agents/skills/local-dev-and-testing/scripts/run-bdd-tests.sh)). O push só prossegue se a aplicação for inicializada com sucesso e responder com HTTP 200 via Gateway API.
