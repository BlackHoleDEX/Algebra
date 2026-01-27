const fs = require('fs');
const path = require('path');

const dataPath = path.join(__dirname, 'simulation/simulationResult.json');
const htmlPath = path.join(__dirname, 'simulation_chart.html');

if (!fs.existsSync(dataPath)) {
    console.error("Error: simulationResult.json not found.");
    process.exit(1);
}

const rawData = fs.readFileSync(dataPath, 'utf8');
const results = JSON.parse(rawData);

const labels = results.map(r => new Date(r.timestamp * 1000).toLocaleTimeString());
const ticks = results.map(r => r.tick);
const volatility = results.map(r => Number(r.volatilityAverage));
const fees = results.map(r => r.fee / 10000.0); // Convert to percentage e.g. 0.5%

const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <title>Adaptive Fee Simulation Result</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: sans-serif; padding: 20px; background: #f4f4f9; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        canvas { margin-bottom: 40px; }
        h1 { text-align: center; color: #333; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Adaptive Fee Simulation (Targets: 25k & 150k)</h1>
        
        <canvas id="priceChart"></canvas>
        <canvas id="volFeeChart"></canvas>
    </div>

    <script>
        const ctxPrice = document.getElementById('priceChart').getContext('2d');
        const ctxVolFee = document.getElementById('volFeeChart').getContext('2d');

        const labels = ${JSON.stringify(labels)};
        const ticks = ${JSON.stringify(ticks)};
        const volatility = ${JSON.stringify(volatility)};
        const fees = ${JSON.stringify(fees)};

        new Chart(ctxPrice, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Tick (Price)',
                    data: ticks,
                    borderColor: 'rgb(75, 192, 192)',
                    tension: 0.1
                }]
            },
            options: { plugins: { title: { display: true, text: 'Simulated Price Movement' } } }
        });

        new Chart(ctxVolFee, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Average Volatility (Raw)',
                        data: volatility,
                        borderColor: 'rgba(54, 162, 235, 0.7)',
                        backgroundColor: 'rgba(54, 162, 235, 0.1)',
                        fill: true,
                        yAxisID: 'yVol'
                    },
                    {
                        label: 'Fee (%)',
                        data: fees,
                        borderColor: 'rgb(255, 99, 132)',
                        borderWidth: 3,
                        yAxisID: 'yFee'
                    }
                ]
            },
            options: {
                scales: {
                    yVol: { type: 'linear', position: 'left', title: { display: true, text: 'Volatility' } },
                    yFee: { type: 'linear', position: 'right', title: { display: true, text: 'Fee (%)' }, min: 0 }
                },
                plugins: { title: { display: true, text: 'Volatility vs Resulting Fee (%)' } }
            }
        });
    </script>
</body>
</html>
`;

fs.writeFileSync(htmlPath, htmlContent);
console.log("Simulation Chart generated at:", htmlPath);
