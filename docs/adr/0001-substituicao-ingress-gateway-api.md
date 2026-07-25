# ADR-001: Substituição do Ingress NGINX pela Kubernetes Gateway API com AWS Load Balancer Controller

* **Status:** Aceito
* **Data:** 2025-11-07
* **Decisores:** Engenheiro Principal de Plataforma & SRE Architect

---

### 1. Contexto e Problema
Tradicionalmente, a exposição de serviços externos no Kubernetes era realizada usando o recurso de `Ingress` e controladores legados como o Ingress NGINX. Embora funcional, o modelo de `Ingress` apresenta limitações sérias para ambientes de nível de produção modernos:
- **Sobrecarga de Configuração (Annotations)**: Funcionalidades avançadas (como redirecionamento, TLS, rate limiting, cabeçalhos customizados) exigem dezenas de anotações proprietárias e não-padronizadas nos recursos de Ingress, gerando incompatibilidades entre provedores de nuvem.
- **Acoplamento de Papéis**: O Ingress unifica a definição de infraestrutura de rede (Load Balancers físicos) com as regras de caminhos de tráfego de aplicação na mesma especificação. Isso impossibilita a segregação de responsabilidades entre engenheiros de plataforma e desenvolvedores de produto.
- **Falta de Integração Nativa**: O Ingress NGINX necessita rodar como um proxy reverso adicional dentro do cluster (gerando custos de computação e latência extra), em vez de se integrar e configurar diretamente os balanceadores de carga nativos de alta performance do provedor de nuvem (como o AWS Application Load Balancer).

### 2. Drivers da Decisão (Critérios de Avaliação)
* **Segurança e Isolamento**: Garantir que desenvolvedores possam expor suas APIs sem precisar alterar configurações globais do Load Balancer ou da infraestrutura base.
* **Padronização e Portabilidade**: Utilizar APIs abertas, extensíveis e oficiais da CNCF, facilitando o design multi-cloud (AWS e GCP).
* **Eficiência e Custos**: Reduzir hops de rede e eliminar pods intermediários de proxy reverso no cluster, aproveitando balanceadores nativos de nuvem (AWS ALB/NLB).

### 3. Opções Consideradas
* **Opção 1: Manutenção do Ingress NGINX Legado**: Manter o Ingress NGINX como proxy reverso, controlando ALBs de forma indireta ou expondo via NodePort/LoadBalancer Service tradicional.
* **Opção 2: Adoção da Kubernetes Gateway API com AWS Load Balancer Controller**: Implementar a especificação moderna de Gateway API (`GatewayClass`, `Gateway`, `HTTPRoute`) acoplada ao AWS Load Balancer Controller para provisionar ALBs de forma nativa e declarativa.

### 4. Decisão Escolhida e Justificação
Escolhemos a **Opção 2 (Kubernetes Gateway API com AWS Load Balancer Controller)**.

Essa decisão foi tomada porque ela fornece uma arquitetura baseada em papéis (Role-Based Design), separando formalmente as responsabilidades operacionais:
1.  **Time de Plataforma**: Define as regras de borda, classes de rede (`GatewayClass`) e provisiona o Load Balancer físico (`Gateway`) na namespace `kube-system`.
2.  **Time de Desenvolvimento**: Define caminhos de roteamento específicos (`HTTPRoute`) para seus microsserviços em suas próprias namespaces de forma autônoma.

Além disso, ela elimina a latência e o custo de sustentar proxies intermediários (como NGINX Pods), visto que o AWS Load Balancer Controller configura as regras diretamente na borda da infraestrutura AWS (Application Load Balancer).

---

### 5. Prós e Contras das Opções

#### Opção 1: Ingress NGINX
* 🟢 **Bom:** Amplamente documentado na comunidade; de fácil adoção inicial para testes locais.
* 🔴 **Mau:** Configuração saturada de annotations proprietárias; hops de rede adicionais; falta de separação nativa de papéis; custos computacionais adicionais para sustentar os proxies.

#### Opção 2: Kubernetes Gateway API & AWS LB Controller
* 🟢 **Bom:** Padrão oficial CNCF moderno; separação estrita de papéis (Plataforma vs. App Dev); integração nativa com o ecossistema AWS (ALB/NLB) e GCP (GCLB); maior performance e menor custo operacional.
* 🔴 **Mau:** Curva de aprendizado inicial para equipes acostumadas ao padrão antigo de Ingress.

---

### 6. Consequências e Impacto
* **Positivas:**
  * Arquitetura de rede limpa, desacoplada, segura e performática.
  * Governança contínua robusta (conseguimos usar políticas OPA Conftest para proibir de forma absoluta a criação de recursos de `Ingress` e forçar o uso da Gateway API).
  * Menor consumo de recursos de CPU e RAM no cluster Kubernetes.
* **Negativas / Riscos:**
  * Exige treinamento básico para que desenvolvedores de microsserviços declarem `HTTPRoute` em vez de `Ingress`.
* **Ações de Mitigação:**
  * Criação do caminho pavimentado (Golden Path) no diretório `apps-template/` contendo o manifesto de exemplo `http-route.yaml` e documentação exaustiva no `README.md` e `PLATFORM.md`.
