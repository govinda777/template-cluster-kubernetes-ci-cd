document.addEventListener('DOMContentLoaded', () => {
    const slider = document.getElementById('traffic-slider');
    const awsPercent = document.getElementById('aws-percentage');
    const gcpPercent = document.getElementById('gcp-percentage');
    const awsWeight = document.getElementById('aws-weight');
    const gcpWeight = document.getElementById('gcp-weight');
    const pieChart = document.getElementById('traffic-chart');
    const domainSelect = document.getElementById('domain-select');
    const cliOutput = document.getElementById('cli-output');
    const applyBtn = document.getElementById('apply-btn');
    const toast = document.getElementById('toast');
    const historyLog = document.getElementById('history-log');

    // Estado inicial
    const state = {
        aws: 50,
        gcp: 50,
        domain: 'n8n.yourcompany.com'
    };

    // Histórico de alterações fictício
    const history = [
        { time: '07/08/2026 00:05', domain: 'n8n.yourcompany.com', split: 'AWS 50% / GCP 50%', status: 'Aplicado' },
        { time: '06/08/2026 14:32', domain: 'api.yourcompany.com', split: 'AWS 70% / GCP 30%', status: 'Aplicado' }
    ];

    function renderHistory() {
        historyLog.innerHTML = history.map(item => `
            <tr>
                <td>${item.time}</td>
                <td>${item.domain}</td>
                <td>${item.split}</td>
                <td><span class="status-badge status-applied">${item.status}</span></td>
            </tr>
        `).join('');
    }

    function updateUI() {
        // Atualiza textos
        awsPercent.textContent = `${state.aws}%`;
        gcpPercent.textContent = `${state.gcp}%`;
        awsWeight.textContent = state.aws;
        gcpWeight.textContent = state.gcp;

        // Atualiza gráfico de pizza
        pieChart.style.background = `conic-gradient(
            var(--aws-color) 0% ${state.aws}%,
            var(--gcp-color) ${state.aws}% 100%
        )`;

        // Atualiza visualização de comando CLI do Route53
        const payload = {
            Comment: `Update traffic split for ${state.domain}`,
            Changes: [
                {
                    Action: "UPSERT",
                    ResourceRecordSet: {
                        Name: state.domain,
                        Type: "A",
                        SetIdentifier: "aws-endpoint",
                        Weight: state.aws,
                        TTL: 60,
                        ResourceRecords: [{ Value: "alb-dns-name.us-east-1.elb.amazonaws.com" }]
                    }
                },
                {
                    Action: "UPSERT",
                    ResourceRecordSet: {
                        Name: state.domain,
                        Type: "A",
                        SetIdentifier: "gcp-endpoint",
                        Weight: state.gcp,
                        TTL: 60,
                        ResourceRecords: [{ Value: "gcp-loadbalancer-ip" }]
                    }
                }
            ]
        };

        const cliCommand = `aws route53 change-resource-record-sets \\
  --hosted-zone-id Z3M3LXXXXXX \\
  --change-batch '${JSON.stringify(payload, null, 2)}'`;

        cliOutput.textContent = cliCommand;
    }

    // Ouvintes de Evento
    slider.addEventListener('input', (e) => {
        state.aws = parseInt(e.target.value);
        state.gcp = 100 - state.aws;
        updateUI();
    });

    domainSelect.addEventListener('change', (e) => {
        state.domain = e.target.value;
        updateUI();
    });

    applyBtn.addEventListener('click', () => {
        // Simular chamada de API do Route 53
        applyBtn.disabled = true;
        applyBtn.textContent = 'Aplicando no Route 53...';

        setTimeout(() => {
            const now = new Date();
            const timeStr = `${String(now.getDate()).padStart(2, '0')}/${String(now.getMonth()+1).padStart(2, '0')}/${now.getFullYear()} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
            
            history.unshift({
                time: timeStr,
                domain: state.domain,
                split: `AWS ${state.aws}% / GCP ${state.gcp}%`,
                status: 'Aplicado'
            });

            renderHistory();
            updateUI();

            // Mostra toast de sucesso
            toast.classList.add('show');
            setTimeout(() => {
                toast.classList.remove('show');
            }, 3000);

            applyBtn.disabled = false;
            applyBtn.textContent = 'Aplicar Pesos no Route 53';
        }, 1200);
    });

    // Inicialização
    updateUI();
    renderHistory();
});
