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

  const entryPointFactory = await hre.ethers.getContractFactory('AlgebraCustomPoolEntryPoint')
  const feeData1 = await getFeeData();
  const entryPoint = await entryPointFactory.deploy(deploysData.factory, { ...feeData1 })

  await entryPoint.waitForDeployment()

  deploysData.entryPoint = entryPoint.target
  console.log('EntryPoint deployed to:', entryPoint.target)

  const factory = await hre.ethers.getContractAt(AlgebraFactoryComplied.abi, deploysData.factory)

  const feeData2 = await getFeeData();
  const deployerRole = await factory.grantRole(
    "0xc9cf812513d9983585eb40fcfe6fd49fbb6a45815663ec33b30a6c6c7de3683b",
    entryPoint.target,
    { ...feeData2 }
  );
  await deployerRole.wait()

  const feeData3 = await getFeeData();
  const administratorRole = await factory.grantRole(
    "0xb73ce166ead2f8e9add217713a7989e4edfba9625f71dfd2516204bb67ad3442",
    entryPoint.target,
    { ...feeData3 }
  );
  await administratorRole.wait()

  const TickLensFactory = await hre.ethers.getContractFactory('TickLens');
  const feeData4 = await getFeeData();
  const TickLens = await TickLensFactory.deploy({ ...feeData4 });

  await TickLens.waitForDeployment();

  deploysData.tickLens = TickLens.target;
  console.log('TickLens deployed to:', TickLens.target);

  const QuoterFactory = await hre.ethers.getContractFactory('Quoter');
  const feeData5 = await getFeeData();
  const Quoter = await QuoterFactory.deploy(
    deploysData.factory,
    WNativeTokenAddress,
    deploysData.poolDeployer,
    { ...feeData5 }
  );

  await Quoter.waitForDeployment();

  deploysData.quoter = Quoter.target;
  console.log('Quoter deployed to:', Quoter.target);

  const QuoterV2Factory = await hre.ethers.getContractFactory('QuoterV2');
  const feeData6 = await getFeeData();
  const QuoterV2 = await QuoterV2Factory.deploy(
    deploysData.factory,
    WNativeTokenAddress,
    deploysData.poolDeployer,
    { ...feeData6 }
  );

  await QuoterV2.waitForDeployment();

  deploysData.quoterV2 = QuoterV2.target;
  console.log('QuoterV2 deployed to:', QuoterV2.target);

  const SwapRouterFactory = await hre.ethers.getContractFactory('SwapRouter');
  const feeData7 = await getFeeData();
  const SwapRouter = await SwapRouterFactory.deploy(
    deploysData.factory,
    WNativeTokenAddress,
    deploysData.poolDeployer,
    { ...feeData7 }
  );

  await SwapRouter.waitForDeployment();

  deploysData.swapRouter = SwapRouter.target;
  console.log('SwapRouter deployed to:', SwapRouter.target);

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

  // const AlgebraInterfaceMulticallFactory = await hre.ethers.getContractFactory('AlgebraInterfaceMulticall');
  // const feeData12 = await getFeeData();
  // const AlgebraInterfaceMulticall = await AlgebraInterfaceMulticallFactory.deploy({ ...feeData12 });

  // await AlgebraInterfaceMulticall.waitForDeployment();

  // console.log('AlgebraInterfaceMulticall deployed to:', AlgebraInterfaceMulticall.target);
  // deploysData.mcall = AlgebraInterfaceMulticall.target;

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
