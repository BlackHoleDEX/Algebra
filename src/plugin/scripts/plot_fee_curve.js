const fs = require('fs');
const path = require('path');

function expXg4(x, g, gHighestDegree) {
    let closestValue;
    let xdg = Math.floor(x / g);
    switch (xdg) {
        case 0: closestValue = BigInt("100000000000000000000"); break;
        case 1: closestValue = BigInt("271828182845904523536"); break;
        case 2: closestValue = BigInt("738905609893065022723"); break;
        case 3: closestValue = BigInt("2008553692318766774092"); break;
        case 4: closestValue = BigInt("5459815003314423907811"); break;
        default: closestValue = BigInt("14841315910257660342111"); break;
    }

    x = x % g;
    let bg = BigInt(g);
    let bx = BigInt(x);

    if (bx >= bg / 2n) {
        bx -= bg / 2n;
        closestValue = (closestValue * BigInt("164872127070012814684")) / BigInt(1e20);
    }

    let xLowestDegree = bx;
    let res = BigInt(gHighestDegree);
    let gHD = BigInt(gHighestDegree);

    gHD /= bg; // g**3
    res += xLowestDegree * gHD;

    gHD /= bg; // g**2
    xLowestDegree *= bx;
    res += (xLowestDegree * gHD) / 2n;

    gHD /= bg; // g
    xLowestDegree *= bx;
    res += (xLowestDegree * bg * 4n + xLowestDegree * bx) / 24n;

    res = (res * closestValue) / BigInt(1e20);
    return res;
}

function sigmoid(x, g, alpha, beta) {
    x = BigInt(x);
    g = BigInt(g);
    alpha = BigInt(alpha);
    beta = BigInt(beta);

    if (x > beta) {
        let diff = x - beta;
        if (diff >= 6n * g) return alpha;
        let g4 = g ** 4n;
        let ex = expXg4(Number(diff), Number(g), g4);
        return (alpha * ex) / (g4 + ex);
    } else {
        let diff = beta - x;
        if (diff >= 6n * g) return 0n;
        let g4 = g ** 4n;
        let ex = g4 + expXg4(Number(diff), Number(g), g4);
        return (alpha * g4) / ex;
    }
}

function calculateFee(volatility, config) {
    let normalizedVol = Math.floor(volatility / 15);
    let s1 = sigmoid(normalizedVol, config.gamma1, config.alpha1, config.beta1);
    let s2 = sigmoid(normalizedVol, config.gamma2, config.alpha2, config.beta2);
    return Number(BigInt(config.baseFee) + s1 + s2) / 10000;
}

const config = {
    alpha1: 4500,
    alpha2: 15000,
    beta1: 1667,
    beta2: 6000,
    gamma1: 400,
    gamma2: 500,
    baseFee: 500
};

const data = [];
for (let v = 0; v <= 150000; v += 1000) {
    data.push({
        volatility: v,
        fee: calculateFee(v, config)
    });
}

const labels = data.map(d => d.volatility);
const fees = data.map(d => d.fee);

const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <title>Adaptive Fee Curve</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: sans-serif; padding: 20px; background: #0f172a; color: white; }
        .container { max-width: 1000px; margin: 0 auto; background: #1e293b; padding: 20px; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.3); }
        h1 { text-align: center; color: #38bdf8; }
        .stats { display: flex; justify-content: space-around; margin-top: 20px; padding: 15px; background: #334155; border-radius: 8px; }
        .stat-item { text-align: center; }
        .stat-value { font-size: 1.2rem; font-weight: bold; color: #fbbf24; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Adaptive Fee Response Curve</h1>
        <canvas id="feeChart"></canvas>
        <div class="stats">
            <div class="stat-item"><div>Base Fee</div><div class="stat-value">0.05%</div></div>
            <div class="stat-item"><div>Max Fee</div><div class="stat-value">2.00%</div></div>
            <div class="stat-item"><div>Current Target (14.5k)</div><div class="stat-value">0.1164%</div></div>
        </div>
    </div>

    <script>
        const ctx = document.getElementById('feeChart').getContext('2d');
        new Chart(ctx, {
            type: 'line',
            data: {
                labels: ${JSON.stringify(labels)},
                datasets: [{
                    label: 'Fee %',
                    data: ${JSON.stringify(fees)},
                    borderColor: '#38bdf8',
                    backgroundColor: 'rgba(56, 189, 248, 0.1)',
                    borderWidth: 3,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0,
                    pointHitRadius: 10
                }]
            },
            options: {
                responsive: true,
                scales: {
                    x: { 
                        title: { display: true, text: 'Raw Volatility', color: '#94a3b8' },
                        grid: { color: '#334155' },
                        ticks: { color: '#94a3b8' }
                    },
                    y: { 
                        title: { display: true, text: 'Fee (%)', color: '#94a3b8' },
                        grid: { color: '#334155' },
                        ticks: { color: '#94a3b8' },
                        min: 0
                    }
                },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        mode: 'index',
                        intersect: false,
                        callbacks: {
                            label: function(context) {
                                return 'Fee: ' + context.parsed.y.toFixed(4) + '%';
                            }
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
`;

const htmlPath = path.join(__dirname, 'fee_curve_plot.html');
fs.writeFileSync(htmlPath, htmlContent);
console.log("Plot generated at:", htmlPath);
