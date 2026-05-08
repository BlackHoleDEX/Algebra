const hre = require('hardhat');
const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');
const AlgebraFactoryComplied = require('@cryptoalgebra/integral-core/artifacts/contracts/AlgebraFactory.sol/AlgebraFactory.json');


async function getFeeData() {
  const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
  return { maxFeePerGas, maxPriorityFeePerGas };
}


async function main() {
  const deployDataPath = path.resolve(__dirname, '../../../'+(process.env.DEPLOY_ENV || '')+'deploys.json');
  let deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));

  // WNativeTokenAddress
  const WNativeTokenAddress = process.env.WNATIVE_TOKEN_ADDRESS;
  if (!WNativeTokenAddress) {
    throw new Error('WNativeToken address is required');
  }
  const NativeTokenTickerName = process.env.NATIVE_TOKEN_TICKER_NAME;
  if (!NativeTokenTickerName) {
    throw new Error('NativeTokenTickerName is required');
  }

  const signers = await hre.ethers.getSigners();
  const ProxyAdmin = signers[0].address;

  deploysData.wrapped = WNativeTokenAddress;

  const NFTDescriptorFactory = await hre.ethers.getContractFactory('NFTDescriptor');
  const feeData8 = await getFeeData();
  const NFTDescriptor = await NFTDescriptorFactory.deploy({ ...feeData8 });
  deploysData.nftDescriptorLibrary = NFTDescriptor.target;

  await NFTDescriptor.waitForDeployment();

  const NonfungibleTokenPositionDescriptorFactory = await hre.ethers.getContractFactory(
    'NonfungibleTokenPositionDescriptor',
    {
      libraries: {
        NFTDescriptor: NFTDescriptor.target,
      },
    }
  );
  const feeData9 = await getFeeData();
  const NonfungibleTokenPositionDescriptor = await NonfungibleTokenPositionDescriptorFactory.deploy(
    WNativeTokenAddress,
    NativeTokenTickerName,
    [],
    { ...feeData9 }
  );

  await NonfungibleTokenPositionDescriptor.waitForDeployment();

  console.log('NonfungibleTokenPositionDescriptor deployed to:', NonfungibleTokenPositionDescriptor.target);
  deploysData.nftDescriptor = NonfungibleTokenPositionDescriptor.target;

  const ProxyFactory = await hre.ethers.getContractFactory('TransparentUpgradeableProxy');
  const feeData10 = await getFeeData();
  const Proxy = await ProxyFactory.deploy(
    NonfungibleTokenPositionDescriptor.target,
    ProxyAdmin,
    '0x',
    { ...feeData10 }
  );

  await Proxy.waitForDeployment();

  deploysData.proxy = Proxy.target;
  deploysData.admin = ProxyAdmin;
  console.log('Proxy deployed to:', Proxy.target);

  const NonfungiblePositionManagerFactory = await hre.ethers.getContractFactory('NonfungiblePositionManager');
  const feeData11 = await getFeeData();
  const NonfungiblePositionManager = await NonfungiblePositionManagerFactory.deploy(
    deploysData.factory,
    WNativeTokenAddress,
    deploysData.nftDescriptor,
    deploysData.poolDeployer,
    { ...feeData11 }
  );

  await NonfungiblePositionManager.waitForDeployment();

  deploysData.nonfungiblePositionManager = NonfungiblePositionManager.target;
  console.log('NonfungiblePositionManager deployed to:', NonfungiblePositionManager.target);

  fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
