# Guia de Engenharia de Plataforma: Observabilidade (Métricas, Logs e Alertas)

Este documento descreve detalhadamente a arquitetura, a configuração e os padrões operacionais da estratégia de **Observabilidade** implementada no cluster Kubernetes através do repositório `template-cluster-kubernetes-ci-cd`.

Esta plataforma padroniza a coleta de telemetria baseada em três pilares integrados: **Métricas (Prometheus)**, **Logs (Grafana Loki)** e **Visualização/Alertas (Grafana e Alertmanager)**, assegurando visibilidade holística e correlação direta de anomalias para SREs, Engenheiros de Plataforma e times de Produto.

---

## 1. Arquitetura Geral de Observabilidade da Plataforma

A pilha de monitoramento foi projetada seguindo o princípio de descentralização de recursos com controle centralizado de infraestrutura. Isso significa que a plataforma fornece os motores de busca e agregação de dados, enquanto os times de produto têm total autonomia para definir quais métricas expor, quais logs emitir e quais alertas acionar para suas respectivas aplicações.

### Fluxo de Coleta e Telemetria no Cluster

O diagrama abaixo ilustra o ciclo de vida dos dados de observabilidade, desde a sua geração na camada física/infraestrutura até a sua consolidação e visualização nos painéis integrados:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        FONTES DE TELEMETRIA (CLUSTER)                 │
│                                                                        │
│  [ Nodes / EC2 ] ──► Node Exporter ──┐                                 │
│  [ Kubernetes ]  ──► Kube-State-Metrics ──┤                            │
│  [ Pods ]        ──► cAdvisor        ──┤ (Métricas Scraping)           │
│  [ Applications ]──► HTTP /metrics   ──┼───────────────────┐           │
│  [ App Containers]──► stdout (Logs)  ──┼─────────┐         │           │
└────────────────────────────────────────┘         │         │
                                                   ▼         ▼
┌──────────────────────────────────────────────────┬─────────────────────┐
│                        CAMADA DE AGREGAÇÃO E STORAGE                   │
│                                                  │                     │
│  [ Loki Agents / Promtail ] ────────────────► Loki (Logs)              │
│  [ Prometheus Server (Pull Model) ] ◄──────────────────────┘           │
│        │                                                               │
│        ▼ (Alertas)                                                     │
│  [ Alertmanager ] ──► Notificações (Slack, Discord, PagerDuty, etc.)   │
└────────┬─────────────────────────────────────────┬─────────────────────┘
         │                                         │
         ▼ (DataSources)                           ▼ (DataSources)
┌────────────────────────────────────────────────────────────────────────┐
│                        CAMADA DE APRESENTAÇÃO                          │
│                                                                        │
│                          [ Grafana Dashboards ]                        │
└────────────────────────────────────────────────────────────────────────┘
```

* **Métricas (Pull-Based):** O **Prometheus** atua de forma ativa, realizando requisições HTTP (`GET /metrics`) em intervalos definidos (geralmente 15s ou 30s) para coletar as métricas expostas pelas ferramentas do cluster (cAdvisor, Node Exporter, Kube-State-Metrics) e pelas aplicações instrumentadas.
* **Logs (Push-Based):** Os agentes coletores de logs de container (e.g., Promtail ou FluentBit) escutam os arquivos de log do Docker/CRI em `/var/log/pods/`, filtram e rotulam as mensagens com base nos metadados do Kubernetes (`namespace`, `pod_name`, `container_name`) e as enviam em lotes para o servidor **Grafana Loki**.
* **Visualização:** O **Grafana** atua como o frontend único de consulta, conectando-se de forma nativa ao Prometheus e ao Loki para plotar gráficos, tabelas e possibilitar a correlação cruzada de dados.

---

## 2. O Helm Chart `kube-prometheus-stack` via ArgoCD

A pilha base de observabilidade é implementada usando o pacote canônico da comunidade **`kube-prometheus-stack`**, empacotado e gerenciado dinamicamente via GitOps pelo ArgoCD no arquivo:

* **Manifesto de Aplicação:** `platform-apps/infrastructure-apps/observability/application.yaml`
* **Customizações de Parâmetros:** `platform-apps/infrastructure-apps/observability/values.yaml`

### Detalhamento das Customizações em `values.yaml`

O arquivo `values.yaml` configura aspectos cruciais de escalabilidade, desempenho e governança para a pilha de monitoramento:

```yaml
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    retention: 15d
    resources:
      limits:
        cpu: 1000m
        memory: 2048Mi
      requests:
        cpu: 500m
        memory: 1024Mi

grafana:
  adminPassword: "admin"
  persistence:
    enabled: true
    size: 10Gi
  additionalDataSources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki.monitoring.svc.cluster.local:3100
      version: 1
      editable: false
```

#### A. A importância de `serviceMonitorSelectorNilUsesHelmValues: false` e `podMonitorSelectorNilUsesHelmValues: false`
Por padrão, quando o Prometheus Operator é instalado via Helm, ele configura o Prometheus para descobrir apenas `ServiceMonitors` e `PodMonitors` que possuam labels específicas correspondentes à própria liberação do Helm Stack (ex: `release: kube-prometheus-stack`).

Ao definir estas duas diretivas como **`false`**, nós removemos essa barreira de segurança e restrição de rótulos. Isso permite que:
* **Descoberta Descentralizada:** O Prometheus busque e monitore de forma automática **qualquer** recurso `ServiceMonitor` ou `PodMonitor` criado em **qualquer namespace** do cluster, independentemente das labels que possuam.
* **Autonomia de Produto:** Os desenvolvedores de software não precisam alterar configurações da stack global de infraestrutura nem pedir autorização ao time de plataforma para monitorar uma nova aplicação; basta publicar o manifesto de monitoramento na pasta de sua aplicação no repositório GitOps.

#### B. Retenção e Alocação de Recursos
* **`retention: 15d`**: Define que os dados de série temporal do Prometheus ficarão armazenados localmente em disco por até 15 dias, garantindo um equilíbrio excelente entre custos de armazenamento de disco persistente (EBS) e capacidade de depuração de histórico recente.
* **Resources (CPU/Memória):** Estabelece limites e requisições explícitos de hardware para evitar que picos repentinos de consultas pesadas de métricas consumam todo o poder de processamento do Worker Node, garantindo a resiliência e a estabilidade da máquina.

#### C. Persistência de Dados e Configurações do Grafana
O Grafana armazena metadados de usuários, dashboards criados interativamente, alertas locais e fontes de dados em um banco de dados interno (geralmente SQLite).
* Ativando **`persistence.enabled: true`** e **`size: 10Gi`**, a plataforma provisiona automaticamente uma Unidade de Armazenamento Persistente (PVC - PersistentVolumeClaim) integrada ao EBS da AWS. Se o Pod do Grafana falhar, reiniciar ou sofrer rescheduling para outro nó de computação, todas as credenciais cadastradas e modificações realizadas persistem de forma 100% segura.

#### D. Integração Nativa de Logs (DataSource Loki)
O arquivo adiciona programaticamente o **Grafana Loki** como um DataSource nativo do Grafana (`http://loki.monitoring.svc.cluster.local:3100`), permitindo que logs e métricas estejam unificados sob a mesma interface gráfica.

---

## 3. Guia Prático para Desenvolvedores: Expondo Métricas e Logs

### A. Expondo Métricas Personalizadas da Aplicação

Para expor métricas ao Prometheus, a aplicação deve disponibilizar uma rota HTTP simples (geralmente `/metrics` ou `/actuator/prometheus`) que retorne as séries temporais em formato plain text seguindo o padrão OpenMetrics.

#### Exemplo de formato de saída de métricas:
```text
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200",path="/checkout"} 1245
http_requests_total{method="POST",status="500",path="/checkout"} 12
```

---

### B. Criando o Recurso `ServiceMonitor`

Para instruir o Prometheus a coletar métricas da sua aplicação a cada 30 segundos, adicione um manifesto do tipo **`ServiceMonitor`** no diretório de infraestrutura do seu serviço (junto aos manifestos do Deployment/Service).

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: payment-service-monitor
  namespace: payment-system
  labels:
    app: payment-service
spec:
  # Indica qual Service do Kubernetes expõe a porta de métricas
  selector:
    matchLabels:
      app: payment-service
  # Define em quais namespaces o Prometheus deve procurar pelo Service correspondente
  namespaceSelector:
    any: false
    matchNames:
      - payment-system
  # Configuração dos endpoints de scraping
  endpoints:
    - port: http-metrics  # Nome da porta definido no Service do Kubernetes
      path: /metrics       # Rota HTTP padrão
      interval: 30s        # Frequência de coleta
      scrapeTimeout: 10s   # Timeout da requisição
```

#### Requisitos para o Service do Kubernetes:
Para que o `ServiceMonitor` consiga se vincular ao seu serviço, garanta que o seu `Service` do Kubernetes defina explicitamente o nome da porta de métricas:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: payment-system
spec:
  ports:
    - name: http-web
      port: 80
      targetPort: 8080
    - name: http-metrics  # Deve coincidir com a propriedade endpoints[].port do ServiceMonitor
      port: 8081
      targetPort: 8081
  selector:
    app: payment-service
```

---

### C. Boas Práticas de Logs para Integração com Grafana Loki

O Grafana Loki indexa logs utilizando metadados (labels) em vez de armazenar o texto em um índice de texto completo. Para usufruir de buscas ultrarrápidas, siga estas diretrizes:

1. **Gere Logs Estruturados em JSON:** Suas aplicações devem imprimir logs em formato JSON no `stdout` ou `stderr`. Isso permite que o Loki analise e crie campos sob demanda (log fields query) sem a necessidade de escrita manual de expressões regulares complexas (LogQL).
   ```json
   {"timestamp":"2026-07-25T14:30:00Z","level":"INFO","service":"payment-service","correlationId":"uuid-1234","message":"Processamento de pagamento aprovado","amount":150.0}
   ```
2. **Evite Logs Multi-linha em Plain Text:** Exceções de pilha (Stack Traces) do Java ou stackdumps do Python não devem ser cuspidas linha por linha no console. Converta-as para logs de linha única encapsulando-as no JSON, evitando a fragmentação do histórico em diferentes blocos no Grafana.

---

## 4. Gerenciamento de Alertas com o Alertmanager

O **Alertmanager** gerencia o ciclo de vida dos alertas emitidos pelo Prometheus, tratando a desduplicação, o agrupamento e o roteamento para destinos de comunicação.

### A. Criando Regras de Alerta (`PrometheusRule`)

Os desenvolvedores podem criar manifestos YAML do tipo **`PrometheusRule`** para definir regras automáticas que acionam notificações em caso de comportamento anômalo da aplicação.

Abaixo está um exemplo completo contendo regras para detectar uso severo de CPU, estouro de memória (potencial OOMKilled) e picos de falha HTTP:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: payment-service-alerts
  namespace: payment-system
  labels:
    role: alert-rules
spec:
  groups:
    - name: PaymentServiceAlertsGroup
      rules:
        # 1. Alerta de Uso Excessivo de CPU no Container
        - alert: ContainerCpuSaturation
          expr: (sum(rate(container_cpu_usage_seconds_total{container="payment-service",namespace="payment-system"}[5m])) by (pod) / sum(kube_pod_container_resource_limits{resource="cpu",container="payment-service",namespace="payment-system"}) by (pod)) * 100 > 90
          for: 5m
          labels:
            severity: warning
            tier: application
          annotations:
            summary: "Saturação de CPU detectada no pod {{ $labels.pod }}"
            description: "O pod {{ $labels.pod }} no namespace payment-system está utilizando mais de 90% do limite de CPU alocado nos últimos 5 minutos."

        # 2. Alerta de Risco iminente de OOMKill (Consumo de Memória > 92%)
        - alert: ContainerMemoryOutofMemoryRisk
          expr: (sum(container_memory_working_set_bytes{container="payment-service",namespace="payment-system"}) by (pod) / sum(kube_pod_container_resource_limits{resource="memory",container="payment-service",namespace="payment-system"}) by (pod)) * 100 > 92
          for: 3m
          labels:
            severity: critical
            tier: application
          annotations:
            summary: "Risco de falta de memória (OOMKill) no pod {{ $labels.pod }}"
            description: "O uso de memória de trabalho do pod {{ $labels.pod }} ultrapassou 92% do limite especificado. Risco iminente de reinicialização forçada do container por OOM."

        # 3. Alerta de Alta Taxa de Erros HTTP 5xx na Aplicação
        - alert: PaymentGatewayHighErrorRate
          expr: (sum(rate(http_requests_total{status=~"5..",namespace="payment-system"}[5m])) / sum(rate(http_requests_total{namespace="payment-system"}[5m]))) * 100 > 5
          for: 2m
          labels:
            severity: critical
            tier: application
          annotations:
            summary: "Taxa de erro HTTP 5xx superior a 5% no Payment Service"
            description: "O Payment Service no namespace payment-system está apresentando uma taxa de erros 5xx de {{ $value | printf \"%.2f\" }}% nas requisições recebidas nos últimos 2 minutos."
```

### B. Roteamento e Destino das Notificações

O Alertmanager unifica e direciona esses alertas usando rotas baseadas nos rótulos definidos (`labels`).
* **Alertas com `severity: warning`:** Enviados para canais não obstrutivos de suporte diurno (e.g., canal `#ops-alerts-warning` no Slack ou Discord).
* **Alertas com `severity: critical`:** Desencadeiam gatilhos de plantão de alta prioridade (e.g., PagerDuty ou Opsgenie para acordar engenheiros de sobreaviso, além de enviar no canal `#ops-alerts-critical` de produção).

---

## 5. Correlação de Dados no Grafana (Métricas para Logs)

Uma das maiores vantagens da nossa arquitetura unificada de observabilidade é a capacidade de realizar **correlação contextual direta** utilizando os metadados do Kubernetes compartilhados entre o Prometheus e o Loki.

### Como funciona o fluxo de correlação (Log Correlation)

1. **Identificação da Anomalia:** Ao analisar um painel do Grafana (alimentado pelo Prometheus), você nota um pico na taxa de erro de requisições ou latência em um pod específico de produção.
2. **Ação de Correlação:** Clique sobre o ponto do gráfico e utilize a opção de navegação contextual do Grafana (**"Explore"**).
3. **Pulo Seguro:** O Grafana transpõe a sua busca abrindo o painel de logs do **Loki** à direita do seu monitor, preservando o intervalo de tempo exato do incidente e aplicando filtros automáticos baseados nas dimensões do gráfico:
   * `{namespace="payment-system", pod="payment-service-abc-123", container="payment-service"}`
4. **Resolução Rápida:** O desenvolvedor consegue correlacionar em segundos o gráfico de oscilação com as stack traces de erro correspondentes que foram salvas no log de console do container naquele milissegundo de tempo, reduzindo drasticamente o **MTTR (Mean Time To Resolution)**.

---

## 6. Boas Práticas de Observabilidade na Plataforma

### A. Prevenção contra Alta Cardinalidade no Prometheus

A cardinalidade é calculada pela multiplicação de todas as dimensões de labels de uma métrica. Alta cardinalidade degrada severamente o desempenho do banco de dados TSDB do Prometheus e pode paralisar as consultas do cluster.

* **O que NÃO utilizar como label do Prometheus:** IDs de transação de banco de dados, chaves de API, e-mails de usuários ou UUIDs temporários.
  ```text
  # RUIM: Alta cardinalidade
  http_requests_total{path="/user/12345/checkout", user_id="12345", correlation_id="abc-987"}
  ```
* **O que UTILIZAR como label:** Códigos HTTP agrupados (`2xx`, `4xx`, `5xx`), caminhos genéricos rotacionados (`/user/{id}/checkout`), ou métodos HTTP (`GET`, `POST`).
  ```text
  # BOM: Cardinalidade previsível e controlada
  http_requests_total{path="/user/:id/checkout", status="2xx", method="POST"}
  ```

### B. Dimensionamento de Recursos de Telemetria

Sempre configure limites e requisições (`resources`) para os coletores e agentes locais que rodam no padrão DaemonSet (como o Promtail/FluentBit).
* Estabeleça regras para limitar o consumo de CPU em períodos de grande volume de tráfego, evitando que agentes de telemetria disputem e roubem recursos computacionais das aplicações de produção de alta prioridade.

### C. Segurança e Rotação de Credenciais

* **Nunca armazene senhas administrativas ou chaves de acesso estáticas em texto claro nos manifestos do Grafana.** Utilize recursos do **AWS Secrets Manager** ou mecanismos como **External Secrets Operator (ESO)** para realizar a injeção de segredos em tempo de execução dentro dos Pods da stack de observabilidade.
* As chaves de acesso de DataSources devem usar autenticação baseada em roles de segurança locais (IRSA / EKS Pod Identity) em vez de credenciais permanentes salvas na interface gráfica do Grafana.
