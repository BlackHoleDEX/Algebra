const hre = require('hardhat')
const fs = require('fs')
const path = require('path')

const BasePluginV3FactoryComplied = require('../../plugin/artifacts/contracts/BasePluginV3Factory.sol/BasePluginV3Factory.json');
const NonfungiblePositionManagerComplied = require('../../periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json');


async function getFeeData() {
  const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
  return { maxFeePerGas, maxPriorityFeePerGas };
}

async function main() {
  const deployDataPath = path.resolve(__dirname, '../../../'+(process.env.DEPLOY_ENV || '')+'deploys.json')
  const deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'))

  const AlgebraEternalFarmingFactory = await hre.ethers.getContractFactory('AlgebraEternalFarming')
  const feeData1 = await getFeeData();
  const AlgebraEternalFarming = await AlgebraEternalFarmingFactory.deploy(
    deploysData.poolDeployer,
    deploysData.nonfungiblePositionManager,
    { ...feeData1 }
  )

  deploysData.eternal = AlgebraEternalFarming.target;

  await AlgebraEternalFarming.waitForDeployment()
  console.log('AlgebraEternalFarming deployed to:', AlgebraEternalFarming.target)

  const FarmingCenterFactory = await hre.ethers.getContractFactory('FarmingCenter')
  const feeData2 = await getFeeData();
  const FarmingCenter = await FarmingCenterFactory.deploy(
    AlgebraEternalFarming.target,
    deploysData.nonfungiblePositionManager,
    { ...feeData2 }
  )

  deploysData.fc = FarmingCenter.target;

  await FarmingCenter.waitForDeployment()
  console.log('FarmingCenter deployed to:', FarmingCenter.target)

  try {
    const feeData3 = await getFeeData();
    await (await AlgebraEternalFarming.setFarmingCenterAddress(FarmingCenter.target, { ...feeData3 })).wait()
    console.log('Updated farming center address in eternal(incentive) farming')
  } catch (e) {
    console.log('setFarmingCenterAddress in AlgebraEternalFarming failed Reason:', e?.message || e);
  }

  if (deploysData.BasePluginV3Factory) {
    const pluginV3Factory = await hre.ethers.getContractAt(BasePluginV3FactoryComplied.abi, deploysData.BasePluginV3Factory)
    try {
      const feeData6 = await getFeeData();
      await (await pluginV3Factory.setFarmingAddress(FarmingCenter.target, { ...feeData6 })).wait()
      console.log('Updated farming center address in BasePluginV3Factory')
    } catch (e) {
      console.log('setFarmingAddress in pluginV3Factory failed Reason:', e?.message || e);
    }
  }

  const posManager = await hre.ethers.getContractAt(
    NonfungiblePositionManagerComplied.abi,
    deploysData.nonfungiblePositionManager
  )
  try {
    const feeData5 = await getFeeData();
    await (await posManager.setFarmingCenter(FarmingCenter.target, { ...feeData5 })).wait()
    console.log('Updated farming center address in posManager')
  }catch (e) {
    console.log('setFarmingCenter in posManager failed Reason:', e?.message || e);
  }

  fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
