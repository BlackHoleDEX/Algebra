const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

const poolAbi = [
    "function plugin() external view returns (address)",
    "function token0() external view returns (address)",
    "function token1() external view returns (address)"
];

const pluginAbi = [
    "function isReflexEnabled() external view returns (bool)",
    "function getRouter() external view returns (address)"
];

const factoryAddress = "0x44B7fBd4D87149eFa5347c451E74B9FD18E89c55";

console.log("Using Factory at:", factoryAddress);

const factoryAbi = [
    "function allPairsLength() external view returns (uint)",
    "function allPairs(uint) external view returns (address)"
];

async function main() {

    const factory = new hre.ethers.Contract(factoryAddress, factoryAbi, hre.ethers.provider);

    const poolLength = await factory.allPairsLength();
    console.log("Total pools:", poolLength.toString());

    const results = [];


    for (let i = 0; i < poolLength; i++) {
        const poolAddress = await factory.allPairs(i);
        const pool = await ethers.getContractAt(poolAbi, poolAddress);
        console.log("Pool:", poolAddress);
        const pluginAddress = await pool.plugin();
        console.log("Plugin:", pluginAddress);

        let reflexEnabled = false;
        let reflexRouter = hre.ethers.ZeroAddress;
        let hasReflex = false;

        // if (pluginAddress !== hre.ethers.ZeroAddress) {
        try {
            const plugin = await ethers.getContractAt(pluginAbi, pluginAddress)

            // Try isReflexEnabled
            // reflexEnabled = await plugin.isReflexEnabled(); 
            console.log("Reflex Enabled:", await plugin.isReflexEnabled());
            hasReflex = true;
        } catch (err) {
            console.log("Error getting reflex enabled:", err);
        }

        const token0 = await pool.token0();
        const token1 = await pool.token1();

        results.push({
            index: i,
            pool: poolAddress,
            tokens: `${token0} / ${token1}`,
            plugin: pluginAddress,
            reflexEnabled: hasReflex ? (reflexEnabled ? "YES" : "NO") : "N/A",
            // reflexRouter: reflexRouter !== hre.ethers.ZeroAddress ? reflexRouter : "N/A" 
        });
    }

    console.table(results);

    const outputPath = path.resolve(__dirname, `../reflex_status_snMainnet.json`);
    fs.writeFileSync(outputPath, JSON.stringify(results, null, 2));
    console.log(`Results saved to ${outputPath}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
