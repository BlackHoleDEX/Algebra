const fs = require('fs');
const path = require('path');

const dataPath = path.join(__dirname, 'timepoints_data.json');
const htmlPath = path.join(__dirname, 'volatility_chart.html');

if (!fs.existsSync(dataPath)) {
    console.error("Error: timepoints_data.json not found. Run read_timepoints.js first.");
    process.exit(1);
}

const rawData = fs.readFileSync(dataPath, 'utf8');
const timepoints = JSON.parse(rawData);

// Sort by timestamp just in case
timepoints.sort((a, b) => a.timestamp - b.timestamp);

const labels = timepoints.map(t => new Date(t.timestamp * 1000).toLocaleString());
const ticks = timepoints.map(t => t.tick);
const averageTicks = timepoints.map(t => t.averageTick);

const WINDOW = 300; // 24 hours

// Mirroring the struct layout
function Timepoint(data) {
    this.blockTimestamp = Number(data.timestamp); // uint32 (using timestamp from JSON)
    this.volatilityCumulative = BigInt(data.volatilityCumulative); // uint88
    this.tickCumulative = BigInt(data.tickCumulative); // int56
    this.tick = Number(data.tick); // int24
    this.averageTick = Number(data.averageTick); // int24
    this.windowStartIndex = Number(data.windowStartIndex); // uint16
    this.initialized = true;
}

// Emulating helper `_lteConsideringOverflow`
// simplified: since we have full JS numbers, we don't strictly typically see overflow logic in the same way,
// but let's assume our input IS sorted / circular-safe.
function _lteConsideringOverflow(a, b, currentTime) {
    // Solidity: res = a > currentTime;
    //           if (res == b > currentTime) res = a <= b;
    let res = a > currentTime;
    if (res === (b > currentTime)) res = a <= b;
    return res;
}

// Emulating internal `_getTimepointsAt`
// In the contract, this performs a binary search on the circular buffer.
// Here `self` is our flat, time-ordered array of timepoints.
// Emulating internal `_binarySearch`
// Performs a binary search (or heuristic search) to find the timepoints surrounding 'target'
function _binarySearch(self, currentTime, target, upperIndex, lowerIndex, withHeuristic) {
    let left = lowerIndex;
    let right = upperIndex < lowerIndex ? upperIndex + 65536 : upperIndex; // We use constant 65536 for UINT16_MODULO

    return _binarySearchInternal(self, currentTime, target, left, right, withHeuristic);
}

function _binarySearchInternal(self, currentTime, target, left, right, withHeuristic) {
    let indexBeforeOrAt = (left + right) >> 1n;

    let beforeOrAt = self[Number(indexBeforeOrAt) % 65536];
    let atOrAfter = beforeOrAt; // to suppress compiler warning; will be overridden
    let firstIteration = true;

    if (withHeuristic && right - left > 2) {
        indexBeforeOrAt = left + 1; // heuristic for first guess
    } else {
        indexBeforeOrAt = (left + right) >> 1; // "middle" point between the boundaries
    }
    beforeOrAt = self[Number(indexBeforeOrAt) % 65536]; // checking the "middle" point between the boundaries
    atOrAfter = beforeOrAt; // to suppress compiler warning; will be overridden
    firstIteration = true;

    do {
        let initializedBefore = beforeOrAt.initialized;
        let timestampBefore = beforeOrAt.blockTimestamp;

        if (initializedBefore) {
            if (_lteConsideringOverflow(timestampBefore, target, currentTime)) {
                // is current point before or at `target`?
                atOrAfter = self[Number(indexBeforeOrAt + 1n) % 65536];
                let initializedAfter = atOrAfter.initialized;
                let timestampAfter = atOrAfter.blockTimestamp;

                if (initializedAfter) {
                    if (_lteConsideringOverflow(target, timestampAfter, currentTime)) {
                        // is the "next" point after or at `target`?
                        return { beforeOrAt, atOrAfter, indexBeforeOrAt };
                    }
                    left = indexBeforeOrAt + 1n; // "next" point is before the `target`, so looking in the right half
                } else {
                    return { beforeOrAt, atOrAfter: beforeOrAt, indexBeforeOrAt };
                }
            } else {
                right = indexBeforeOrAt - 1n; // current point is after the `target`, so looking in the left half
            }
        } else {
            // we've landed on an uninitialized timepoint, keep searching higher
            left = indexBeforeOrAt + 1n;
        }

        // use heuristic if looking in the right half after first iteration
        let useHeuristic = firstIteration && withHeuristic && left == indexBeforeOrAt + 1n;
        if (useHeuristic && right - left > 16n) {
            indexBeforeOrAt = left + 8n;
        } else {
            indexBeforeOrAt = (left + right) >> 1n; // calculating the new "middle" point index after updating the bounds
        }
        beforeOrAt = self[Number(indexBeforeOrAt) % 65536];
        firstIteration = false;

        if (left > right) break; // Defensive JS
    } while (true);

    return { beforeOrAt, atOrAfter, indexBeforeOrAt };
}

// Emulating internal `_getTimepointsAt`
function _getTimepointsAt(self, currentTime, target, lastIndex, oldestIndex) {
    const lastTimepoint = self[Number(lastIndex) % 65536];
    const lastTimepointTimestamp = lastTimepoint.blockTimestamp;
    const windowStartIndex = lastTimepoint.windowStartIndex;

    // if target is newer than last timepoint
    if (target === currentTime || _lteConsideringOverflow(lastTimepointTimestamp, target, currentTime)) {
        return { beforeOrAt: lastTimepoint, atOrAfter: lastTimepoint, samePoint: true, indexBeforeOrAt: lastIndex };
    }

    let useHeuristic = false;

    // Check if we can limit scope using windowStartIndex
    if (lastTimepointTimestamp - target <= WINDOW) {
        // We can limit the scope of the search. It is safe because when the array overflows,
        // `windowsStartIndex` cannot point to the overwritten timepoint (check at `write(...)`)
        oldestIndex = windowStartIndex;
        useHeuristic = (target == currentTime - WINDOW); // heuristic will optimize search for timepoints close to `currentTime - WINDOW`
    }

    let oldestTimepoint = self[Number(oldestIndex) % 65536];
    const oldestTimestamp = oldestTimepoint.blockTimestamp;

    if (!_lteConsideringOverflow(oldestTimestamp, target, currentTime)) return { beforeOrAt: null };
    if (oldestTimestamp == target) return { beforeOrAt: oldestTimepoint, atOrAfter: oldestTimepoint, samePoint: true, indexBeforeOrAt: oldestIndex };

    // no need to search if we already know the answer
    if (lastIndex == initialOldestIndex + 1) return { beforeOrAt: oldestTimepoint, atOrAfter: lastTimepoint, samePoint: false, indexBeforeOrAt: initialOldestIndex };

    const { beforeOrAt, atOrAfter, indexBeforeOrAt } = _binarySearch(self, currentTime, target, lastIndex, initialOldestIndex, useHeuristic);
    return { beforeOrAt, atOrAfter, samePoint: false, indexBeforeOrAt };
}

// Emulating `_volatilityOnRange` from Solidity
function _volatilityOnRange(dt, tick0, tick1, avgTick0, avgTick1) {
    // dt: int256, tick0: int256, tick1: int256, avgTick0: int256, avgTick1: int256
    const k = BigInt(tick1 - tick0) - BigInt(avgTick1 - avgTick0);
    const b = BigInt(tick0 - avgTick0) * BigInt(dt);
    const sumOfSequence = BigInt(dt) * (BigInt(dt) + 1n);
    const sumOfSquares = sumOfSequence * (2n * BigInt(dt) + 1n);

    // (k ** 2 * sumOfSquares + 6 * b * k * sumOfSequence + 6 * dt * b ** 2) / (6 * dt ** 2)
    const dt2 = BigInt(dt) ** 2n;
    const numerator = (k ** 2n * sumOfSquares) + (6n * b * k * sumOfSequence) + (6n * BigInt(dt) * b ** 2n);
    const denominator = 6n * dt2;

    return numerator / denominator;
}

// Emulating `_getTickCumulativeAt` from Solidity
function _getTickCumulativeAt(self, time, secondsAgo, tick, lastIndex, oldestIndex) {
    const target = time - secondsAgo;
    const { beforeOrAt, atOrAfter, samePoint, indexBeforeOrAt } = _getTimepointsAt(self, time, target, lastIndex, oldestIndex);

    const timestampBefore = beforeOrAt.blockTimestamp;
    const tickCumulativeBefore = beforeOrAt.tickCumulative;

    if (target === timestampBefore) return [tickCumulativeBefore, indexBeforeOrAt];

    if (samePoint) {
        return [tickCumulativeBefore + BigInt(tick) * BigInt(target - timestampBefore), indexBeforeOrAt];
    }

    const timestampAfter = atOrAfter.blockTimestamp;
    const tickCumulativeAfter = atOrAfter.tickCumulative;

    if (target === timestampAfter) return [tickCumulativeAfter, indexBeforeOrAt + 1];

    const timepointTimeDelta = BigInt(timestampAfter - timestampBefore);
    const targetDelta = BigInt(target - timestampBefore);

    return [
        tickCumulativeBefore + ((tickCumulativeAfter - tickCumulativeBefore) / timepointTimeDelta) * targetDelta,
        indexBeforeOrAt
    ];
}

// Emulating `_getAverageTick` from Solidity
function _getAverageTick(self, currentTime, tick, lastIndex, oldestIndex, lastTimestamp, lastTickCumulative) {
    const oldestTimestamp = self[oldestIndex].blockTimestamp;
    const oldestTickCumulative = self[oldestIndex].tickCumulative;

    const currentTickCumulative = lastTickCumulative + BigInt(tick) * BigInt(currentTime - lastTimestamp);

    if (!_lteConsideringOverflow(oldestTimestamp, currentTime - WINDOW, currentTime)) {
        if (currentTime === oldestTimestamp) return [tick, oldestIndex];
        return [Number((currentTickCumulative - oldestTickCumulative) / BigInt(currentTime - oldestTimestamp)), oldestIndex];
    }

    if (_lteConsideringOverflow(lastTimestamp, currentTime - WINDOW, currentTime)) {
        return [tick, lastIndex];
    } else {
        const [tickCumulativeAtStart, windowStartIndex] = _getTickCumulativeAt(self, currentTime, WINDOW, tick, lastIndex, oldestIndex);
        const avgTick = Number((currentTickCumulative - tickCumulativeAtStart) / BigInt(WINDOW));
        return [avgTick, windowStartIndex];
    }
}

// Emulating `_getAverageTickCasted` from Solidity
function _getAverageTickCasted(self, time, tick, lastIndex, oldestIndex, lastTimestamp, lastTickCumulative) {
    const [avgTick, windowStartIndex] = _getAverageTick(self, time, tick, lastIndex, oldestIndex, lastTimestamp, lastTickCumulative);
    return [avgTick, windowStartIndex];
}

// Emulating `_getVolatilityCumulativeAt`
// Note: Arguments mirror Solidity exactly
function _getVolatilityCumulativeAt(self, time, secondsAgo, tick, lastIndex, oldestIndex) {
    const target = time - secondsAgo;

    const { beforeOrAt, atOrAfter, samePoint, indexBeforeOrAt } = _getTimepointsAt(self, time, target, lastIndex, oldestIndex);

    if (!beforeOrAt) return 0n; // Fallback

    const timestampBefore = beforeOrAt.blockTimestamp;
    const volatilityCumulativeBefore = beforeOrAt.volatilityCumulative;

    if (target === timestampBefore) return volatilityCumulativeBefore; // left boundary

    if (samePoint) {
        const [avgTick] = _getAverageTickCasted(self, target, tick, lastIndex, oldestIndex, timestampBefore, beforeOrAt.tickCumulative);

        return (volatilityCumulativeBefore +
            BigInt(_volatilityOnRange(target - timestampBefore, tick, tick, beforeOrAt.averageTick, avgTick)));
    }

    const timestampAfter = atOrAfter.blockTimestamp;
    const volatilityCumulativeAfter = atOrAfter.volatilityCumulative;

    if (target === timestampAfter) return volatilityCumulativeAfter; // right boundary

    // Middle interpolation
    const timepointTimeDelta = BigInt(timestampAfter - timestampBefore);
    const targetDelta = BigInt(target - timestampBefore);

    return volatilityCumulativeBefore + ((volatilityCumulativeAfter - volatilityCumulativeBefore) / timepointTimeDelta) * targetDelta;
}


// Emulating `getAverageVolatility`
// Note: Arguments mirror Solidity exactly
function getAverageVolatility(
    self,
    currentTime,
    tick,
    lastIndex,
    oldestIndex
) {
    const lastTimepoint = self[Number(lastIndex) % 65536];
    const timeAtLastTimepoint = lastTimepoint.blockTimestamp === currentTime;
    let lastCumulativeVolatility = lastTimepoint.volatilityCumulative;
    const windowStartIndex = BigInt(lastTimepoint.windowStartIndex); // index of timepoint before of at lastTimepoint.blockTimestamp - WINDOW

    if (!timeAtLastTimepoint) {
        lastCumulativeVolatility = _getVolatilityCumulativeAt(self, currentTime, 0, tick, lastIndex, oldestIndex);
    }

    const oldestTimestamp = self[Number(oldestIndex) % 65536].blockTimestamp;
    if (_lteConsideringOverflow(oldestTimestamp, currentTime - WINDOW, currentTime)) {
        // oldest timepoint is earlier than 24 hours ago
        let cumulativeVolatilityAtStart;
        if (timeAtLastTimepoint) {
            // interpolate cumulative volatility to avoid search. Since the last timepoint has _just_ been written, we know for sure
            // that the start of the window is between windowStartIndex and windowStartIndex + 1

            let startPoint = self[Number(windowStartIndex) % 65536];
            let startPointNext = self[Number(windowStartIndex + 1n) % 65536];

            let startTimestamp = startPoint.blockTimestamp;
            cumulativeVolatilityAtStart = startPoint.volatilityCumulative;

            const timeDeltaBetweenPoints = BigInt(startPointNext.blockTimestamp - startTimestamp);

            cumulativeVolatilityAtStart +=
                ((startPointNext.volatilityCumulative - cumulativeVolatilityAtStart) * BigInt(currentTime - WINDOW - startTimestamp)) /
                timeDeltaBetweenPoints;
        } else {
            cumulativeVolatilityAtStart = _getVolatilityCumulativeAt(self, currentTime, WINDOW, tick, lastIndex, oldestIndex);
        }

        return Number((lastCumulativeVolatility - cumulativeVolatilityAtStart) / BigInt(WINDOW)); // sample is big enough to ignore bias of variance
    } else if (currentTime !== oldestTimestamp) {
        // recorded timepoints are not enough, so we will extrapolate
        const _oldestVolatilityCumulative = self[Number(oldestIndex) % 65536].volatilityCumulative;
        let unbiasedDenominator = currentTime - oldestTimestamp;
        if (unbiasedDenominator > 1) unbiasedDenominator--; // Bessel's correction for "small" sample
        return Number((lastCumulativeVolatility - _oldestVolatilityCumulative) / BigInt(unbiasedDenominator));
    }
    return 0;
}

const avgVolatility24h = [];

// Prepare data structure for "self"
// The helpers expect a random-access collection where we can look up by index.
// Our `timepoints` is that array.
// `lastIndex` will act as `i` in our loop (the point we are conceptually "at").
// `oldestIndex` will always be 0 (the start of our fetched history).

const mappedTimepoints = timepoints.map(t => ({ ...new Timepoint(t), index: Number(t.index) }));

// Emulating the storage layout: Timepoint[65536] self
const selfBuffer = new Array(65536).fill(null).map(() => ({ initialized: false }));

for (let i = 0; i < mappedTimepoints.length; i++) {
    const current = mappedTimepoints[i];

    // Write current point into buffer to simulate contract storage
    selfBuffer[current.index] = current;

    const currentTime = current.blockTimestamp;
    const tick = current.tick;
    const lastIndex = BigInt(current.index);
    const oldestIndex = BigInt(mappedTimepoints[0].index); // Our fetched history's oldest point

    const val = getAverageVolatility(
        selfBuffer,
        currentTime,
        tick,
        lastIndex,
        oldestIndex
    );

    avgVolatility24h.push(val);
}


const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <title>Volatility Oracle Data</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: sans-serif; padding: 20px; background: #f4f4f9; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        canvas { margin-bottom: 40px; }
        h1 { text-align: center; color: #333; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Volatility Oracle Visualization</h1>
        
        <canvas id="priceChart"></canvas>
        <canvas id="volChart"></canvas>
    </div>

    <script>
        const ctxPrice = document.getElementById('priceChart').getContext('2d');
        const ctxVol = document.getElementById('volChart').getContext('2d');

        const labels = ${JSON.stringify(labels)};
        const ticks = ${JSON.stringify(ticks)};
        const averageTicks = ${JSON.stringify(averageTicks)};
        const volatility = ${JSON.stringify(avgVolatility24h)};

        new Chart(ctxPrice, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Tick (Spot Price)',
                        data: ticks,
                        borderColor: 'rgb(75, 192, 192)',
                        tension: 0.1,
                        yAxisID: 'y'
                    },
                    {
                        label: 'Average Tick (24h Avg)',
                        data: averageTicks,
                        borderColor: 'rgb(255, 99, 132)',
                        borderDash: [5, 5],
                        tension: 0.1,
                        yAxisID: 'y'
                    }
                ]
            },
            options: {
                responsive: true,
                interaction: { mode: 'index', intersect: false },
                plugins: { title: { display: true, text: 'Price vs Average Price' } }
            }
        });

        new Chart(ctxVol, {
            type: 'line', // Changed to line for tracking average
            data: {
                labels: labels,
                datasets: [{
                    label: '24h Average Volatility',
                    data: volatility,
                    backgroundColor: 'rgba(54, 162, 235, 0.5)',
                    borderColor: 'rgb(54, 162, 235)',
                    borderWidth: 2,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                plugins: { title: { display: true, text: '24-Hour Average Volatility' } }
            }
        });
    </script>
</body>
</html>
`;

fs.writeFileSync(htmlPath, htmlContent);
console.log("Chart generated at:", htmlPath);
