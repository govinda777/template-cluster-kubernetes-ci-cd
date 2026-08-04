# ADR 0007: Teste Integrado de Destruição e Reconstrução de Ambientes Multi-Cloud (AWS e GCP)

## Status
Aprovado

## Contexto
O ciclo de vida da infraestrutura multi-cloud (AWS EKS e GCP GKE) envolve criação, destruição parcial e reconstrução total (Clean Slate). Durante testes ou descontinuação de ambientes, surgem problemas recorrentes:
1. **Recursos Órfãos e Travamento de Redes:** Dispositivos de balanceamento de carga (`LoadBalancer` e `Gateway` API) provisionados dinamicamente pelos controladores de Kubernetes na AWS (ELB/NLB) e GCP associam-se às subredes. Se o Terraform tentar destruir a VPC antes que estes recursos sejam limpos no Kubernetes, o processo falha ou entra em loop infinito aguardando a liberação dos ENIs (Elastic Network Interfaces).
2. **Dependência de Tokens de Acesso:** Em ambientes CI, o token do GCP é mockado (`dummy-access-token-to-bypass-ci-initialization`) quando a implantação do GKE está desativada (`enable_gke=false`). No entanto, ao disparar a destruição total, se o GKE já estava ativo no estado, o Terraform falha ao tentar destruir o recurso sem um token válido.
3. **Validação de Onboarding/Day 0:** É necessário garantir que, após uma destruição total, o script de bootstrap OIDC/WIF seja capaz de recriar as identidades e atualizar os segredos do repositório no GitHub automaticamente.

---

## Decisão

Adotamos a especificação de um pipeline de teste integrado de destruição e reconstrução chamado **Destroy & Recreate (Clean Slate Test)**, automatizado no arquivo [scripts/destroy-recreate-test.sh](file:///Users/govinda/projetos/template-cluster-kubernetes-ci-cd/scripts/destroy-recreate-test.sh) e exposto via Makefile como `make run clean-slate`.

### 1. Mecanismo de Pre-Clean (Kubernetes Teardown)
Antes do início da destruição pelo Terraform/OpenTofu, o script conecta-se aos contextos dos clusters (EKS e GKE) e força a remoção de todos os recursos de rede dinâmicos:
```bash
kubectl delete gateway --all --all-namespaces --timeout=60s
kubectl delete httproute --all --all-namespaces --timeout=30s
kubectl delete svc --all --all-namespaces --field-selector metadata.name!=kubernetes
```
Isso garante a desalocação imediata de ALBs, NLBs e IP addresses associados na AWS e GCP, permitindo que as VPCs sejam excluídas sem falhas de timeout.

### 2. Tratamento Dinâmico de Provedores na Destruição
Para contornar o problem do token GCP ao destruir recursos legados no state, a destruição do ambiente Dev é tentada primeiro com `enable_gke=true` (utilizando as credenciais ativas do gcloud) e, caso falhe ou o cluster não esteja mais presente, faz-se um fallback de limpeza com `enable_gke=false`.

### 3. Fluxo de Execução do Teste Integrado
O script executa as seguintes etapas sequenciais:
1. **Pre-clean do Kubernetes** em todos os clusters ativos (AWS & GCP).
2. **Destruição do Dev** (`terraform/live/dev`) passando variáveis reais da nuvem.
3. **Destruição do Prod** (`terraform/live/prod`).
4. **Destruição do Bootstrap** (`terraform/bootstrap`) removendo os OIDC Providers e IAM Roles.
5. **Execução do Bootstrap Multicloud** (`scripts/bootstrap-multicloud.sh`) para recriar toda a fundação de identidades e backends.
6. **Re-aplicação do Dev** (`terraform/live/dev` com `enable_gke=true`) para provar que a infraestrutura se reconstrói perfeitamente do zero.

---

## Consequências

* **Pontos Positivos:**
  * **Confiabilidade:** Elimina erros comuns de destruição e travamento de VPCs.
  * **Automação de Day 0:** Garante que qualquer alteração no código de bootstrap/IaC seja testada contra um ciclo de vida real completo (Destruição + Reconstrução).
  * **Segurança:** Atualiza e recria todos os segredos OIDC/WIF nos repositórios GitHub.

* **Pontos de Atenção:**
  * **Tempo de Execução:** O teste integrado completo pode levar de 20 a 40 minutos para provisionar e destruir os clusters gerenciados (EKS e GKE).
