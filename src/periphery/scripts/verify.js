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

  // Verify TickLens
  await verifyContract('TickLens', {
    address: deploysData.tickLens,
    constructorArguments: [],
  });

  // Verify EntryPoint
  await verifyContract('EntryPoint', {
    address: deploysData.entryPoint,
    constructorArguments: [deploysData.factory],
  });

  // Verify Quoter
  await verifyContract('Quoter', {
    address: deploysData.quoter,
    constructorArguments: [deploysData.factory, deploysData.wrapped, deploysData.poolDeployer],
  });

  // Verify QuoterV2
  await verifyContract('QuoterV2', {
    address: deploysData.quoterV2,
    constructorArguments: [deploysData.factory, deploysData.wrapped, deploysData.poolDeployer],
  });

  // Verify SwapRouter
  await verifyContract('SwapRouter', {
    address: deploysData.swapRouter,
    constructorArguments: [deploysData.factory, deploysData.wrapped, deploysData.poolDeployer],
  });

  // Verify Proxy
  await verifyContract('Proxy', {
    address: deploysData.proxy,
    constructorArguments: [deploysData.nftDescriptor, deploysData.admin, '0x'],
  });

  // Verify NFTDescriptor
  await verifyContract('NonfungibleTokenPositionDescriptor', {
    address: deploysData.nftDescriptor,
    constructorArguments: [deploysData.wrapped, 'ETH', []],
  });

  // Verify NFTDescriptorLibrary
  await verifyContract('NFTDescriptor', {
    address: deploysData.nftDescriptorLibrary,
    constructorArguments: [],
  });

  // Verify NonfungiblePositionManager
  await verifyContract('NonfungiblePositionManager', {
    address: deploysData.nonfungiblePositionManager,
    constructorArguments: [deploysData.factory, deploysData.wrapped, deploysData.proxy, deploysData.poolDeployer],
  });

  // Verify Multicall
  await verifyContract('Multicall', {
    address: deploysData.mcall,
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
