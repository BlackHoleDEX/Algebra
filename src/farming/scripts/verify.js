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

  // Verify EternalFarming
  await verifyContract('EternalFarming', {
    address: deploysData.eternal,
    constructorArguments: [deploysData.poolDeployer, deploysData.nonfungiblePositionManager],
  });

  // Verify FarmingCenter
  await verifyContract('FarmingCenter', {
    address: deploysData.fc,
    constructorArguments: [deploysData.eternal, deploysData.nonfungiblePositionManager],
  });

  /*
    // TODO:: VERIFY EternalVirtualPool
    await verifyContract('EternalVirtualPool', {
        address: "0x45204AC8f938b44bfb0f19be6d2794EeFBfe08B2",
        constructorArguments: ["0x01A8A00A6fC8106B94f84aAbAef689Fd0D77271A", "0xdB2093a4DF635dcE499A0db0BBA9ABe39dB6594A"],
    });*/
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });