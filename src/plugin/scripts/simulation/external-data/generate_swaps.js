const fs = require('fs');
const path = require('path');

const swaps = [];
let currentTimestamp = 1700000000;
let currentTick = 10000;

function addSwap(timeDelta, tickDelta) {
    currentTimestamp += timeDelta;
    currentTick += tickDelta;
    swaps.push({
        timestamp: currentTimestamp,
        tick: currentTick
    });
}

// 1. Stable period (3x density, higher volatility)
for (let i = 0; i < 90; i++) {
    addSwap(7, Math.floor(Math.random() * 40) - 20);
}

// 2. Upward trend (3x density, higher volatility)
for (let i = 0; i < 90; i++) {
    addSwap(7, 50 + Math.floor(Math.random() * 100));
}

// 3. Volatility Spike (3x density, higher volatility)
for (let i = 0; i < 90; i++) {
    // Sharp drop then recovery
    let delta = i < 45 ? -400 : 400;
    addSwap(7, delta + Math.floor(Math.random() * 200) - 100);
}

// 4. Oscillating period (3x density, higher volatility)
for (let i = 0; i < 90; i++) {
    addSwap(7, (i % 2 === 0 ? 800 : -800) + Math.floor(Math.random() * 150));
}

// 5. Final steady climb (3x density, higher volatility)
for (let i = 0; i < 180; i++) {
    addSwap(7, 15 + Math.floor(Math.random() * 60));
}

const outputPath = path.resolve(__dirname, 'swaps.json');
fs.writeFileSync(outputPath, JSON.stringify(swaps, null, 2));
console.log(`Generated ${swaps.length} swaps to ${outputPath}`);
