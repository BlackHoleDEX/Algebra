const hre = require('hardhat');
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

  const [deployer] = await hre.ethers.getSigners();

  // Verify Factory
  await verifyContract('AlgebraFactory', {
    address: deploysData.factory,
    constructorArguments: [deploysData.poolDeployer],
  });

  // Verify Pool Deployer
  await verifyContract('AlgebraPoolDeployer', {
    address: deploysData.poolDeployer,
    constructorArguments: [deploysData.factory],
  });

  // Verify Vault Factory
  await verifyContract('AlgebraVaultFactory', {
    contract: 'contracts/AlgebraVaultFactory.sol:AlgebraVaultFactory',
    address: deploysData.vaultFactory,
    constructorArguments: [deploysData.factory],
  });

  /*TO VERIFY AlgebraPool.sol*/
  // await verifyContract('AlgebraPool', {
  //   address: '0xd0533118e1849C78d770ec4b1212B0099a0Bf315',
  //   constructorArguments: [],
  // });

  // Verify Vault (commented out)
  // await verifyContract('AlgebraCommunityVault', {
  //   address: deploysData.vault,
  //   constructorArguments: [deploysData.factory, deployer.address],
  // });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
