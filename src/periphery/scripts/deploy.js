const hre = require('hardhat');
const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');
const AlgebraFactoryComplied = require('@cryptoalgebra/integral-core/artifacts/contracts/AlgebraFactory.sol/AlgebraFactory.json');

async function main() {
  const deployDataPath = path.resolve(__dirname, '../../../'+(process.env.DEPLOY_ENV || '')+'deploys.json');
  let deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));

  // WNativeTokenAddress
  const WNativeTokenAddress = '0xb3B3CbEd8243682845C2ff23Ea1FD48e6144E34F';
  const signers = await hre.ethers.getSigners();
  const ProxyAdmin = signers[0].address;

  deploysData.wrapped = WNativeTokenAddress;

  const entryPointFactory = await hre.ethers.getContractFactory('AlgebraCustomPoolEntryPoint')
  const feeData1 = await hre.ethers.provider.getFeeData();
  const entryPoint = await entryPointFactory.deploy(deploysData.factory, { ...feeData1 })

  await entryPoint.waitForDeployment()

  deploysData.entryPoint = entryPoint.target
  console.log('EntryPoint deployed to:', entryPoint.target)

  const factory = await hre.ethers.getContractAt(AlgebraFactoryComplied.abi, deploysData.factory)

  const feeData2 = await hre.ethers.provider.getFeeData();
  const deployerRole = await factory.grantRole(
    "0xc9cf812513d9983585eb40fcfe6fd49fbb6a45815663ec33b30a6c6c7de3683b",
    entryPoint.target,
    { ...feeData2 }
  );
  await deployerRole.wait()

  const feeData3 = await hre.ethers.provider.getFeeData();
  const administratorRole = await factory.grantRole(
    "0xb73ce166ead2f8e9add217713a7989e4edfba9625f71dfd2516204bb67ad3442",
    entryPoint.target,
    { ...feeData3 }
  );
  await administratorRole.wait()

  const TickLensFactory = await hre.ethers.getContractFactory('TickLens');
  const feeData4 = await hre.ethers.provider.getFeeData();
  const TickLens = await TickLensFactory.deploy({ ...feeData4 });

  await TickLens.waitForDeployment();

  deploysData.tickLens = TickLens.target;
  console.log('TickLens deployed to:', TickLens.target);

  const QuoterFactory = await hre.ethers.getContractFactory('Quoter');
  const feeData5 = await hre.ethers.provider.getFeeData();
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
  const feeData6 = await hre.ethers.provider.getFeeData();
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
  const feeData7 = await hre.ethers.provider.getFeeData();
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
  const feeData8 = await hre.ethers.provider.getFeeData();
  const NFTDescriptor = await NFTDescriptorFactory.deploy({ ...feeData8 });

  await NFTDescriptor.waitForDeployment();

  const NonfungibleTokenPositionDescriptorFactory = await hre.ethers.getContractFactory(
    'NonfungibleTokenPositionDescriptor',
    {
      libraries: {
        NFTDescriptor: NFTDescriptor.target,
      },
    }
  );
  const feeData9 = await hre.ethers.provider.getFeeData();
  const NonfungibleTokenPositionDescriptor = await NonfungibleTokenPositionDescriptorFactory.deploy(
    WNativeTokenAddress,
    'AVAX',
    [],
    { ...feeData9 }
  );

  await NonfungibleTokenPositionDescriptor.waitForDeployment();

  console.log('NonfungibleTokenPositionDescriptor deployed to:', NonfungibleTokenPositionDescriptor.target);
  deploysData.nftDescriptor = NonfungibleTokenPositionDescriptor.target;

  const ProxyFactory = await hre.ethers.getContractFactory('TransparentUpgradeableProxy');
  const feeData10 = await hre.ethers.provider.getFeeData();
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
  const feeData11 = await hre.ethers.provider.getFeeData();
  const NonfungiblePositionManager = await NonfungiblePositionManagerFactory.deploy(
    deploysData.factory,
    WNativeTokenAddress,
    Proxy.target,
    deploysData.poolDeployer,
    { ...feeData11 }
  );

  await NonfungiblePositionManager.waitForDeployment();

  deploysData.nonfungiblePositionManager = NonfungiblePositionManager.target;
  console.log('NonfungiblePositionManager deployed to:', NonfungiblePositionManager.target);

  const AlgebraInterfaceMulticallFactory = await hre.ethers.getContractFactory('AlgebraInterfaceMulticall');
  const feeData12 = await hre.ethers.provider.getFeeData();
  const AlgebraInterfaceMulticall = await AlgebraInterfaceMulticallFactory.deploy({ ...feeData12 });

  await AlgebraInterfaceMulticall.waitForDeployment();

  console.log('AlgebraInterfaceMulticall deployed to:', AlgebraInterfaceMulticall.target);
  deploysData.mcall = AlgebraInterfaceMulticall.target;

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
