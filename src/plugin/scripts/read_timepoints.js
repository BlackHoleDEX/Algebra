const { ethers } = require("hardhat");

async function main() {
    // Get the plugin address from arguments
    // Since hardhat puts network args in process.argv, we look for the first arg that looks like an address
    // or just assume it's passed differently. Easiest is to look for the last arg or specific flag.
    // However, clean usage with hardhat run is: `npx hardhat run script.js --network localhost` (no args support easily without parsing)
    // So we'll look at process.env.PLUGIN_ADDRESS or just parse argv for a 0x string.


    const algebraPoolAddress = "0x1ec2D78ABe5a1b9bd8C4e56f0e67575DBec10E36";

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
        const ENTRIES_TO_SHOW = currentIndex;
        console.log(`Fetching the last ${ENTRIES_TO_SHOW} entries...`);

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
        }

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
