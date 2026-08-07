# ADR 0008: Instalação e Configuração do n8n no Cluster Kubernetes Local e Multi-Cloud

## Status
Aprovado

## Contexto
O n8n é uma ferramenta de automação de fluxo de trabalho baseada em nós altamente flexível. Para integrá-lo à nossa plataforma Kubernetes (tanto local no Kind quanto multi-cloud em AWS/GCP), precisamos garantir:
1. **Persistência de Dados:** O n8n precisa salvar seus fluxos e execuções em um banco de dados persistente (PostgreSQL).
2. **Exposição de Rede Unificada:** O acesso ao painel do n8n deve passar pela **Gateway API**, utilizando `HTTPRoute` em conformidade com o ADR 0001 e o ADR 0006.
3. **Suporte de Ambiente Híbrido:** O manifesto deve funcionar tanto em produção (AWS/GCP) quanto localmente (Kind) sem conflitos ou modificações manuais invasivas de arquivos de infraestrutura.

---

## Decisão

Adotamos as seguintes especificações para a implantação do n8n:

### 1. Separação de Namespaces e Banco de Dados
* O n8n será provisionado no namespace `platform-tools`.
* A persistência local será feita conectando o n8n a uma instância PostgreSQL provisionada no namespace `database`.
* Para viabilizar a execução local offline e sem Helm, criamos uma especificação simplificada de banco de dados PostgreSQL (`postgresql-dev`) local no namespace `database` contendo a senha definida no Secret `postgresql-dev-credentials`.

### 2. Configuração de Rede com Gateway API
* Criamos um `HTTPRoute` apontando para o Gateway `main-aws-alb-gateway` no namespace `kube-system`.
* Em ambientes locais (Kind), para emular o comportamento do AWS Application Load Balancer sem alterar o `parentRefs` do `HTTPRoute`, provisionamos um `GatewayClass` (`eg`) e um `Gateway` local com o nome `main-aws-alb-gateway` no namespace `kube-system`.
* A rota de acesso local será exposta via encaminhamento de porta (`port-forward`) automático na porta `5678`.

### 3. Automação do Bootstrapping Local
* O script de setup local `setup-local-env.sh` foi estendido para:
  1. Criar os namespaces necessários (`database`, `platform-tools`).
  2. Aplicar as credenciais do PostgreSQL e o deployment local de banco de dados.
  3. Aplicar a configuração do n8n (ServiceAccount, Deployment, Service, HTTPRoute).
  4. Aplicar o Gateway e GatewayClass locais para viabilizar o roteamento de tráfego.
  5. Iniciar o port-forwarding para a porta `5678` e exibir a URL de acesso no console.

---

## Consequências

* **Pontos Positivos:**
  * **Consistência de Ambiente:** A mesma infraestrutura de Gateway API e HTTPRoute é testada localmente e replicada para a nuvem.
  * **Facilidade de Uso:** O usuário recebe a URL pronta para uso do n8n no término da inicialização do cluster.
  * **Persistência:** Todos os fluxos criados no n8n persistirão localmente no container PostgreSQL.

* **Pontos de Atenção:**
  * **Segurança de Credenciais:** As credenciais PostgreSQL para desenvolvimento local usam segredos mockados padrão. Para produção na AWS/GCP, devem ser usados segredos injetados pelo AWS Secrets Manager/External Secrets.
