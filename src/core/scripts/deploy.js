const hre = require('hardhat');
const fs = require('fs');
const path = require('path');

async function getFeeData() {
  const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
  return { maxFeePerGas, maxPriorityFeePerGas };
}

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying ${deployer.address}`);

  // precompute
  const poolDeployerAddress = hre.ethers.getCreateAddress({
    from: deployer.address,
    nonce: (await hre.ethers.provider.getTransactionCount(deployer.address)) + 1,
  });

  const AlgebraFactory = await hre.ethers.getContractFactory('AlgebraFactory');
  const feeData1 = await getFeeData();
  const factory = await AlgebraFactory.deploy(poolDeployerAddress, feeData1);

  await factory.waitForDeployment();

  const PoolDeployerFactory = await hre.ethers.getContractFactory('AlgebraPoolDeployer');
  const feeData2 = await getFeeData();
  const poolDeployer = await PoolDeployerFactory.deploy(factory.target, feeData2);

  await poolDeployer.waitForDeployment();

  console.log('AlgebraPoolDeployer to:', poolDeployer.target);
  console.log('AlgebraFactory deployed to:', factory.target);

  // const vaultFactory = await hre.ethers.getContractFactory('AlgebraCommunityVault');
  // const feeData3 = await getFeeData();
  // const vault = await vaultFactory.deploy(factory, deployer.address, feeData3);
  // await vault.waitForDeployment();
  // console.log('AlgebraCommunityVault deployed to:', vault.target);

  const vaultFactoryStubFactory = await hre.ethers.getContractFactory('AlgebraVaultFactory');
  const feeData4 = await getFeeData();
  const vaultFactoryStub = await vaultFactoryStubFactory.deploy(factory.target, feeData4);

  await vaultFactoryStub.waitForDeployment();

  console.log('AlgebraVaultFactoryStub deployed to:', vaultFactoryStub.target);

  const feeData5 = await getFeeData();
  const setVaultTx = await factory.setVaultFactory(vaultFactoryStub);
  await setVaultTx.wait();

  // protocol fee settings
  // const algebraFeeRecipient = "0x8ec18CcA7E8d40861dc07C217a6426f60005A661"
  // const partnerAddress = "0x8ec18CcA7E8d40861dc07C217a6426f60005A661" // owner address, must be changed
  const algebraFeeShare = 20; // specified on algebraVault, 100% of community fee by default(3% of all fees)
  const defaultCommunityFee = 0; // 3% by default

  const feeData6 = await getFeeData();
  const setCommunityFeeTx = await factory.setDefaultCommunityFee(defaultCommunityFee, feeData6);
  await setCommunityFeeTx.wait();

  // const feeData7 = await getFeeData();
  // const changeAlgebraFeeReceiverTx = await vault.changeAlgebraFeeReceiver(algebraFeeRecipient, feeData7)
  // await changeAlgebraFeeReceiverTx.wait()

  // const feeData8 = await getFeeData();
  // const changePartnerFeeReceiverTx = await vault.changeCommunityFeeReceiver(partnerAddress, feeData8)
  // await changePartnerFeeReceiverTx.wait()

  // const feeData9 = await getFeeData();
  // await (await vault.proposeAlgebraFeeChange(algebraFeeShare, feeData9)).wait()

  // const feeData10 = await getFeeData();
  // await (await vault.acceptAlgebraFeeChangeProposal(algebraFeeShare, feeData10)).wait()

  // const feeData11 = await getFeeData();
  // await (await factory.transferOwnership(partnerAddress, feeData11)).wait()

  const deployDataPath = path.resolve(__dirname, '../../../' + (process.env.DEPLOY_ENV || '') + 'deploys.json');
  let deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));
  deploysData.poolDeployer = poolDeployer.target;
  deploysData.factory = factory.target;
  // deploysData.vault = vault.target;
  deploysData.vaultFactory = vaultFactoryStub.target;
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
