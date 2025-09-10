const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {

    const deployDataPath = path.resolve(__dirname, '../../../'+(process.env.DEPLOY_ENV || '')+'deploys.json');
    let deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));

    const BasePluginV1Factory = deploysData.BasePluginV1Factory;
    const AlgebraFarmingProxyPluginFactory = deploysData.AlgebraFarmingProxyPluginFactory;

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


     /* TODO:: VERIFY AlgebraFarmingProxyPlugin
      await hre.run('verify:verify', {
        address: "0xdB2093a4DF635dcE499A0db0BBA9ABe39dB6594A",
        constructorArguments: ["0x41100C6D2c6920B10d12Cd8D59c8A9AA2eF56fC7", "0x512eb749541B7cf294be882D636218c84a5e9E5F", "0x27ae8c52A41EC52A4150BA6321007eC41702c0F0"],
      });*/
    
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });