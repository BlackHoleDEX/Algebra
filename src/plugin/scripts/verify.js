const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {

    const deployDataPath = path.resolve(__dirname, '../../../'+(process.env.DEPLOY_ENV || '')+'deploys.json');
    let deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));

    const BasePluginV1Factory = deploysData.BasePluginV1Factory;
    const AlgebraFarmingProxyPluginFactory = deployDataPath.AlgebraFarmingProxyPluginFactory;

    await hre.run("verify:verify", {
        address: BasePluginV1Factory,
        constructorArguments: [
            deploysData.factory
        ],
        });

    await hre.run("verify:verify", {
        address: AlgebraFarmingProxyPluginFactory,
        constructorArguments: [],
        });
    
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });