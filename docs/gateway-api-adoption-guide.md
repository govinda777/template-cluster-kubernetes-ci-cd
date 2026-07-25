# Guia de Adoção Técnica: Kubernetes Gateway API

> **Caminho do Arquivo Recomendado:** `docs/gateway-api-adoption-guide.md`
>
> **Aplica-se ao Repositório:** `template-cluster-kubernetes-ci-cd`
>
> **Público-Alvo:** Engenheiros de Plataforma (SRE/DevOps) e Engenheiros de Software (Product Teams)

---

## 1. Visão Geral e Contexto

A infraestrutura do `template-cluster-kubernetes-ci-cd` padroniza a publicação de serviços na AWS utilizando a **Kubernetes Gateway API** (`gateway.networking.k8s.io/v1`) em substituição à especificação legada de **Ingress** (`networking.k8s.io/v1`).

### Por que substituímos o Ingress legado?

* **Descontinuação e Estagnação:** O projeto `ingress-nginx` encontra-se em modo de suporte crítico e estagnação de novas funcionalidades.
* **Anotações Monolíticas:** O Ingress tradicional dependia do uso excessivo de anotações específicas do provedor (como `alb.ingress.kubernetes.io/...`), sem validação formal de esquema YAML.
* **Acoplamento de Responsabilidades:** No Ingress, as configurações de infraestrutura (certificados TLS, Load Balancers) e as regras de rotas da aplicação ficavam misturadas no mesmo manifesto, gerando riscos de segurança e gargalos de permissões.

---

### Arquitetura Orientada a Papéis (Role-Oriented Architecture)

A Gateway API resolve o acoplamento dividindo o gerenciamento de rede em três recursos com responsabilidades bem definidas:

| Recurso | Nível de Atuação | Responsável | Descrição / Atribuições |
| --- | --- | --- | --- |
| **`GatewayClass`** | Infraestrutura Global | Cloud Architect / Infra | Define o controlador subjacente (ex.: AWS Load Balancer Controller). |
| **`Gateway`** | Plataforma / Cluster | Engenheiro de Plataforma | Provisiona os pontos de entrada físicos/virtuais (portas 80/443, TLS, ALBs). |
| **`HTTPRoute`** | Aplicação | Desenvolvedor / Product Team | Mapeia caminhos, cabeçalhos, métodos HTTP e direciona o tráfego aos Services. |

---

### Diagrama Conceitual de Relacionamento

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        INFRAESTRUTURA / CLOUD                          │
│                                                                        │
│   [ GatewayClass: alb ] (Definido pelo AWS Load Balancer Controller)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        PLATAFORMA (kube-system)                        │
│                                                                        │
│   [ Gateway: main-aws-alb-gateway ] (Provisiona AWS ALB + Cert TLS)    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Attaches (parentRefs)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        APLICAÇÃO (namespace: app)                      │
│                                                                        │
│   [ HTTPRoute: my-app-route ] ────► [ Service A ] ────► Pods v1 (80%)  │
│                               └────► [ Service B ] ────► Pods v2 (20%)  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Guia Prático para Desenvolvedores (How-To)

Como desenvolvedor, você só precisa criar e manter o recurso `HTTPRoute` dentro do diretório de manifestos da sua aplicação (ex.: `apps-template/base/http-route.yaml`).

### Padrão de Conexão (`parentRefs`)

Todo `HTTPRoute` deve obrigatoriamente apontar para o `Gateway` mantido pela equipe de plataforma. No nosso cluster, a referência padrão é:

* **Name:** `main-aws-alb-gateway`
* **Namespace:** `kube-system`

---

### Exemplos Práticos de `HTTPRoute`

#### A. Roteamento por Caminho (`PathPrefix` e `Exact`)

O exemplo abaixo demonstra como rotear todo o tráfego da API por prefixo e uma rota exata de auditoria:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: api-service-route
  namespace: payment-system
spec:
  parentRefs:
    - name: main-aws-alb-gateway
      namespace: kube-system
  hostnames:
    - "api.empresa.com"
  rules:
    # Rota 1: Match por Prefixo
    - matches:
        - path:
            type: PathPrefix
            value: /v1/payments
      backendRefs:
        - name: payment-service-v1
          port: 8080
    # Rota 2: Match Exato
    - matches:
        - path:
            type: Exact
            value: /v1/audit-log
      backendRefs:
        - name: audit-service
          port: 8080
```

---

#### B. Roteamento baseado em Headers e Métodos HTTP

Útil para isolar chamadas de depuração ou direcionar requisições específicas (`POST`/`GET`) para microsserviços otimizados:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: header-method-route
  namespace: order-system
spec:
  parentRefs:
    - name: main-aws-alb-gateway
      namespace: kube-system
  hostnames:
    - "orders.empresa.com"
  rules:
    # Direciona chamadas com Header "X-Beta-Feature: true" e método POST
    - matches:
        - headers:
            - name: X-Beta-Feature
              value: "true"
          method: POST
          path:
            type: PathPrefix
            value: /checkout
      backendRefs:
        - name: checkout-service-beta
          port: 8080
    # Rota padrão para requisições normais
    - matches:
        - path:
            type: PathPrefix
            value: /checkout
      backendRefs:
        - name: checkout-service-stable
          port: 8080
```

---

#### C. Divisão de Tráfego (Traffic Splitting / Canary Deployments)

Para realizar implantações estilo Canary, defina os pesos (`weight`) entre múltiplos `backendRefs`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canary-traffic-split-route
  namespace: store-frontend
spec:
  parentRefs:
    - name: main-aws-alb-gateway
      namespace: kube-system
  hostnames:
    - "loja.empresa.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        # 90% do tráfego vai para a versão estável
        - name: frontend-v1
          port: 80
          weight: 90
        # 10% do tráfego vai para a versão canary
        - name: frontend-v2
          port: 80
          weight: 10
```

---

#### D. Redirecionamento de HTTP para HTTPS

O redirecionamento global pode ser gerenciado no próprio `HTTPRoute` com o filtro `RequestRedirect`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: http-to-https-redirect
  namespace: default
spec:
  parentRefs:
    - name: main-aws-alb-gateway
      namespace: kube-system
      sectionName: http-listener # Listener da porta 80 do Gateway
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
```

---

## 3. Governança e Pipeline de CI/CD

Para garantir que o padrão Gateway API seja respeitado em todos os microsserviços, o pipeline de CI/CD em `.github/workflows/ci-cd.yml` executa validações automatizadas com **OPA / Conftest** utilizando a política em `tests/policies/gateway-api-enforcement.rego`.

### A Política Rego (`gateway-api-enforcement.rego`)

```rego
package main

# 1. Proíbe expressamente a criação de recursos Ingress legados
deny[msg] {
    input.apiVersion == "networking.k8s.io/v1"
    input.kind == "Ingress"
    msg := sprintf("REJEITADO: O manifesto '%s' utiliza a Ingress API legada. Utilize a Gateway API (HTTPRoute).", [input.metadata.name])
}

# 2. Exige que todo HTTPRoute possua um parentRef apontando para o Gateway de infraestrutura
deny[msg] {
    input.kind == "HTTPRoute"
    not input.spec.parentRefs[_].name
    msg := sprintf("REJEITADO: O HTTPRoute '%s' deve conter obrigatoriamente um 'parentRef' válido.", [input.metadata.name])
}
```

---

### Diagnóstico de Erros Comuns no CI/CD

Se o seu Pull Request falhar na etapa de linting estático, verifique as mensagens de erro comuns:

#### Erro 1: `REJEITADO: O manifesto '...' utiliza a Ingress API legada. Utilize a Gateway API (HTTPRoute).`
* **Causa:** O repositório contém um arquivo YAML com `kind: Ingress`.
* **Solução:** Remova o arquivo de Ingress e crie um manifesto com `kind: HTTPRoute`.

#### Erro 2: `REJEITADO: O HTTPRoute '...' deve conter obrigatoriamente um 'parentRef' válido.`
* **Causa:** O manifesto `HTTPRoute` não declarou o bloco `parentRefs` ou o campo `name` está vazio.
* **Solução:** Adicione a referência ao Gateway global:
```yaml
spec:
  parentRefs:
    - name: main-aws-alb-gateway
      namespace: kube-system
```

---

## 4. Estratégia de Observabilidade e Descoberta de Status

A sustentação operacional e a visibilidade de saúde da Gateway API baseiam-se em três pilares fundamentais: **Métricas**, **Logs** e **Rastreabilidade/Dashboards**. Isso garante que tanto Engenheiros de Plataforma quanto Desenvolvedores consigam auditar o tráfego, identificar gargalos e diagnosticar falhas de forma ativa.

### A. Fluxo Geral de Telemetria de Entrada

```text
  [ Tráfego de Entrada ]
           │
           ▼
  [ AWS Application LB ] ──────► Logs de Acesso (Enviados ao Bucket S3)
           │
           ▼ (Métricas CloudWatch: TargetResponseTime, ActiveConnectionCount)
  [ Target Groups (Pods) ]
           │
           ▼ (Prometheus Scraping / ServiceMonitor)
  [ Prometheus Server ] ◄─────── Métricas do AWS LB Controller (AWS API rate limits, etc.)
           │
           ▼
  [ Grafana Dashboards ] ◄────── Loki Logs Server (Logs dos Pods do Controller e do App)
```

---

### B. Principais Métricas Prometheus para Monitoramento

Para acompanhar o status das rotas de entrada, monitoramos os seguintes conjuntos de métricas nativas do ecossistema EKS e AWS Load Balancer Controller:

#### 1. Métricas de Volume e Disponibilidade de Tráfego (CloudWatch Exporter / Prometheus)
* **`aws_alb_request_count_sum`**: Total de requisições recebidas pelo Application Load Balancer. Útil para medir volumetria geral.
* **`aws_alb_httpcode_target_2xx_count_sum` / `3xx` / `4xx` / `5xx`**: Códigos de resposta de HTTP retornados pelos Pods de backend. Um pico inesperado de `5xx` sinaliza erros severos na camada da aplicação ou falha de timeout.
* **`aws_alb_httpcode_elb_5xx_count_sum`**: Códigos de erro `5xx` originados diretamente pelo próprio ALB (e.g., quando não há Pods saudáveis no Target Group, gerando `502 Bad Gateway`).

#### 2. Métricas de Performance e Latência
* **`aws_alb_target_response_time_average`**: Tempo médio que a aplicação leva para responder após receber a requisição do ALB. Essencial para monitorar degradação de desempenho.

#### 3. Métricas de Saúde de Recursos de Rede (Control Plane)
* **`aws_alb_healthy_host_count_average`**: Número de instâncias/IPs de Pods classificados como saudáveis no Target Group.
* **`aws_alb_un_healthy_host_count_average`**: Número de hosts/IPs falhando no health check do ALB. **Gera alertas críticos imediatos para o time de SRE.**

---

### C. Estratégia de Logs de Acesso (Auditoria de Tráfego)

Para fins de conformidade jurídica, auditoria de segurança e diagnóstico detalhado de falhas no nível de requisição, o ALB armazena logs estruturados contendo informações de latência de ponta a ponta, TLS negotiation, user-agents, IPs de origem e destino:

1. **Destino dos Logs**: Armazenados em um bucket S3 centralizado e seguro (`s3://company-alb-access-logs/`).
2. **Ciclo de Vida (LifeCycle)**: Retenção automática de 90 dias em classe standard e transição automática para Cold Storage (Glacier Deep Archive) por até 1 ano.
3. **Análise de Logs**: Integrados ao **Amazon Athena** para consultas ad-hoc via SQL e ao **Grafana Loki** (usando log-forwarders autorizados) para indexação rápida associada ao container.

---

### D. Dashboards de Observabilidade (Golden Path)

Os times de SRE e Produto têm acesso a painéis Grafana pré-configurados que agregam dados de telemetria das rotas:

1. **Dashboard do Time de Desenvolvimento (Application Gateway View)**:
   * **Métricas em Foco**: Taxa de erros por `HTTPRoute`, latência por rota (P95/P99), volumetria de requisições por segundo (RPS) e status de sincronização da rota (`Accepted` / `Reconciled`).
2. **Dashboard do Time de Plataforma (AWS Ingress Controller View)**:
   * **Métricas em Foco**: API limits da AWS para evitar throttling, latência de reconcile das modificações do Gateway, volumetria consolidada e integridade de saúde de todos os TargetGroups vinculados ao cluster.

---

### E. Alertas Críticos no Slack/Discord (Alertmanager)

No ambiente de produção, regras automatizadas notificam os times responsáveis em caso de indisponibilidade ou desvio severo do comportamento esperado:

```yaml
groups:
  - name: GatewayAPIErrors
    rules:
      # Alerta se o ALB detectar que não há destinos saudáveis (Downtime Total)
      - alert: NoHealthyPodsInTargetGroup
        expr: aws_alb_healthy_host_count_average == 0
        for: 2m
        labels:
          severity: critical
          tier: platform
        annotations:
          summary: "Zero pods saudáveis detectados para o Target Group."
          description: "O ALB não consegue rotear o tráfego porque todos os Pods vinculados ao Target Group estão falhando no Health Check."

      # Alerta para aumento expressivo de erros 5XX (Falha de Aplicação)
      - alert: HighHttp5xxErrorRate
        expr: (sum(rate(aws_alb_httpcode_target_5xx_count_sum[5m])) / sum(rate(aws_alb_request_count_sum[5m]))) * 100 > 5
        for: 3m
        labels:
          severity: warning
          tier: application
        annotations:
          summary: "Taxa de erro HTTP 5xx acima de 5% no ALB."
          description: "O serviço está retornando códigos HTTP 5xx para mais de 5% das requisições de entrada nos últimos 5 minutos."
```

---

## 5. Guia de Resolução de Problemas (Troubleshooting)

### Inspeção de Recursos via `kubectl`

Quando uma rota não responder como esperado, inspecione a árvore de eventos dos recursos:

```bash
# 1. Verificar o status e a sincronização do HTTPRoute
kubectl describe httproute <NOME_DO_HTTPROUTE> -n <NAMESPACE>

# 2. Verificar se o Gateway pai aceitou o vínculo com a sua rota
kubectl describe gateway main-aws-alb-gateway -n kube-system

# 3. Inspecionar as ligações de Target Group criadas pelo AWS Load Balancer Controller
kubectl get targetgroupbindings -n <NAMESPACE>
```

---

### Integração AWS Load Balancer Controller & Target Groups

Ao integrar a Gateway API com a AWS, a criação do Application Load Balancer (ALB) e dos Target Groups é gerenciada dinamicamente pelo controlador. Preste atenção aos seguintes pontos arquiteturais:

---

#### 1. Modos de Endereçamento: `IP` vs `Instance`

| Tipo de Target | Padrão Recomendado | Funcionamento | Regras de Security Group |
| --- | --- | --- | --- |
| **`ip`** | **Sim (Recomendado)** | O ALB envia o tráfego diretamente para o Pod IP, ignorando Kube-Proxy/NodePort. | O Security Group do ALB precisa permitir tráfego diretamente na faixa de CIDR da VPC para os Pods. |
| **`instance`** | Não | O ALB envia o tráfego para a NodePort das instâncias EC2 antes de chegar ao Pod. | O SG do ALB precisa de permissão de acesso à NodePort nos Security Groups dos Nós EKS. |

---

#### 2. Obrigatoriedade do `Pod Readiness Gates` (Target Type `ip`)

Ao operar com `targetType: ip`, a comunicação entra direto da AWS VPC para o Container. Para evitar *downtime* ou envio de requisições para Pods em fase de inicialização, habilite o **Pod Readiness Gate**:

* O **AWS Load Balancer Controller** injeta uma condição `target-health.elbv2.k8s.aws` no `.status.conditions` do Pod.
* O Pod permanecerá no estado de inicialização até que o ALB confirme o status `Healthy` no Target Group da AWS.

Sua namespace deve possuir a label para injeção automática ou o Deployment deve conter a especificação:

```yaml
spec:
  template:
    spec:
      readinessGates:
        - conditionType: "target-health.elbv2.k8s.aws/k8s-payment-system-payment-service-v1"
```

---

#### 3. Checklist de Problemas Frequentes

1. **HTTPRoute com status `Accepted: False`:**
   * Verifique se o nome e a namespace declarados no `parentRef` existem no cluster e aceitam conexões da sua namespace (veja a propriedade `allowedRoutes` no recurso `Gateway`).

2. **ALB retorna `502 Bad Gateway` ou `504 Gateway Timeout`:**
   * Inspecione o Target Group no console da AWS ou via CLI:
     ```bash
     aws elbv2 describe-target-health --target-group-arn <TG_ARN>
     ```
   * Verifique se os Pods da aplicação estão ouvindo exatamente na porta mapeada pelo `service.spec.ports[].targetPort`.
   * Certifique-se de que o Security Group dos Worker Nodes permite tráfego vindo do Security Group do ALB.

3. **Subnets não encontradas pelo AWS Load Balancer Controller:**
   * Certifique-se de que as VPC Subnets do cluster possuem as seguintes tags da AWS:
     * **Subnets Públicas:** `kubernetes.io/role/elb = 1`
     * **Subnets Privadas:** `kubernetes.io/role/internal-elb = 1`
