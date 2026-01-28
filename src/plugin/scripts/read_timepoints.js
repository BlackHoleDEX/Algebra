const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');

// Get pool address from: 1) CLI arg, 2) env var, 3) default
function getPoolAddress() {
    // Check for CLI argument (look for 0x... pattern)
    const cliArg = process.argv.find(arg => arg.startsWith('0x') && arg.length === 42);
    if (cliArg) return cliArg;

    // Check environment variable
    if (process.env.POOL_ADDRESS) return process.env.POOL_ADDRESS;

    // Default fallback
    return "0xbCf4A97e83eBF99C06Caa904db6bee53025e804F";
}

async function main() {
    const algebraPoolAddress = getPoolAddress();

    console.log(`\n========================================`);
    console.log(`  Read Timepoints Script`);
    console.log(`========================================`);
    console.log(`Pool Address: ${algebraPoolAddress}\n`);

    // We assume the pool exposes a 'plugin' method or variable
    console.log(`Connecting to AlgebraPool at: ${algebraPoolAddress}`);
    const AlgebraPool = await ethers.getContractAt("IAlgebraPool", algebraPoolAddress);
    const pluginAddress = await AlgebraPool.plugin();
    console.log(`Fetching Plugin Address from Pool... Found: ${pluginAddress}`);

    if (pluginAddress === ethers.ZeroAddress) {
        console.error("Error: Plugin address is the Zero Address. Is a plugin attached?");
        process.exit(1);
    }

    console.log(`Connecting to VolatilityOraclePlugin at: ${pluginAddress}`);

    // Define the minimal ABI needed to read timepoints
    const abi = [
        "function timepointIndex() external view returns (uint16)",
        "function timepoints(uint256) external view returns (bool initialized, uint32 blockTimestamp, int56 tickCumulative, uint88 volatilityCumulative, int24 tick, int24 averageTick, uint16 windowStartIndex)"
    ];

    const plugin = new ethers.Contract(pluginAddress, abi, ethers.provider);

    try {
        // 1. Get the current timepoint index (where the last write happened)
        const currentIndex = await plugin.timepointIndex();
        console.log(`\nLatest Timepoint Index (Cursor): ${currentIndex}`);

        // 2. Read the last 5 timepoints to show the history
        const ENTRIES_TO_SHOW = Number(currentIndex) + 1;
        console.log(`Fetching the last ${ENTRIES_TO_SHOW} entries...`);

        const timepointsData = [];

        for (let i = 0; i < ENTRIES_TO_SHOW; i++) {
            // Calculate index respecting the circular buffer (mod 65536)
            let index = Number(currentIndex) - i;
            if (index < 0) index += 65536;

            const timepoint = await plugin.timepoints(index);

            console.log(`\n---------------------------------------------------`);
            console.log(`Index: ${index} ${i === 0 ? "(LATEST)" : ""}`);
            console.log(`---------------------------------------------------`);
            if (!timepoint.initialized) {
                console.log("Status: NOT INITIALIZED");
                continue;
            }

            console.log(`Timestamp:             ${timepoint.blockTimestamp} (${new Date(Number(timepoint.blockTimestamp) * 1000).toLocaleString()})`);
            console.log(`Tick (Price):          ${timepoint.tick}`);
            console.log(`Average Tick:          ${timepoint.averageTick}`);
            console.log(`Volatility Cumulative: ${timepoint.volatilityCumulative}`);
            console.log(`Tick Cumulative:       ${timepoint.tickCumulative}`);
            console.log(`Window Start Index:    ${timepoint.windowStartIndex}`);

            const entry = {
                index: index,
                isLatest: i === 0,
                timestamp: Number(timepoint.blockTimestamp),
                timestampHuman: new Date(Number(timepoint.blockTimestamp) * 1000).toLocaleString(),
                tick: Number(timepoint.tick),
                averageTick: Number(timepoint.averageTick),
                volatilityCumulative: timepoint.volatilityCumulative.toString(),
                tickCumulative: timepoint.tickCumulative.toString(),
                windowStartIndex: Number(timepoint.windowStartIndex)
            };

            timepointsData.push(entry);

            console.log(`Read index ${index}...`);
        }

        // Output filename includes pool address for Jenkins
        const outputFilename = `timepoints_${algebraPoolAddress}.json`;
        const outputPath = path.join(__dirname, outputFilename);

        fs.writeFileSync(outputPath, JSON.stringify(timepointsData, null, 2));
        console.log(`\n✅ Successfully wrote ${timepointsData.length} timepoints to: ${outputPath}`);

        // Also output the path for downstream scripts
        console.log(`\nOUTPUT_FILE=${outputPath}`);
        console.log(`POOL_ADDRESS=${algebraPoolAddress}`);

    } catch (error) {
        console.error("\nError feching data:", error.message);
        console.error("Make sure you are connected to the correct network and the address is a VolatilityOraclePlugin.");
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
