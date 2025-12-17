const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function verifyContract(contractName, verifyOptions) {
  try {
    console.log(`\n🔍 Verifying ${contractName}...`);
    await hre.run('verify:verify', verifyOptions);
    console.log(`✅ ${contractName} verified successfully`);
  } catch (error) {
    console.log(`⚠️  ${contractName} verification completed with status check error (contract may still be verified)`);
    console.log(`Error details: ${error.message}`);
  }
}

async function main() {
  const deployDataPath = path.resolve(__dirname, '../../../' + (process.env.DEPLOY_ENV || '') + 'deploys.json');
  let deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));

  const BasePluginV3Factory = deploysData.BasePluginV3Factory;
  const PluginV3Deployer = deploysData.PluginV3Deployer;
  const SecurityRegistry = deploysData.SecurityRegistry;
  const FeeDiscountRegistry = deploysData.FeeDiscountRegistry;

  // Verify BasePluginV3Factory
  if (BasePluginV3Factory) {
    await hre.run("verify:verify", {
      address: BasePluginV3Factory,
      constructorArguments: [
        deploysData.factory
      ],
    });
  }

  // Verify PluginV3Deployer
  if (PluginV3Deployer) {
    await hre.run("verify:verify", {
      address: PluginV3Deployer,
      constructorArguments: [],
    });
  }

  // Verify SecurityRegistry
  if (SecurityRegistry) {
    await hre.run("verify:verify", {
      address: SecurityRegistry,
      constructorArguments: [
        deploysData.factory
      ],
    });
  }

  // Verify FeeDiscountRegistry
  if (FeeDiscountRegistry) {
    await hre.run("verify:verify", {
      address: FeeDiscountRegistry,
      constructorArguments: [
        deploysData.factory
      ],
    });
  }

  /* TODO:: VERIFY AlgebraFarmingProxyPlugin
    await verifyContract('AlgebraFarmingProxyPlugin', {
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