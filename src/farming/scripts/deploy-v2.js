const hre = require('hardhat')
const fs = require('fs')
const path = require('path')
const BasePluginV1FactoryComplied = require('@cryptoalgebra/integral-base-plugin/artifacts/contracts/BasePluginV1Factory.sol/BasePluginV1Factory.json')

async function getFeeData() {
  const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData()
  return { maxFeePerGas, maxPriorityFeePerGas }
}

async function main() {
  const deployDataPath = path.resolve(__dirname, '../../../' + (process.env.DEPLOY_ENV || '') + 'deploys.json')
  const deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'))

  if (!deploysData.eternal) throw new Error('deploys.json missing "eternal" address')
  if (!deploysData.nonfungiblePositionManager) throw new Error('deploys.json missing "nonfungiblePositionManager" address')
  if (!deploysData.BasePluginV1Factory) throw new Error('deploys.json missing "BasePluginV1Factory" address')
  const legacyFarmingCenter = deploysData.fcV1 || deploysData.fc
  if (!legacyFarmingCenter) throw new Error('deploys.json missing legacy farming center address ("fc" or "fcV1")')

  const FarmingCenterV2Factory = await hre.ethers.getContractFactory('FarmingCenterV2')
  const feeData1 = await getFeeData()
  const farmingCenterV2 = await FarmingCenterV2Factory.deploy(
    deploysData.eternal,
    deploysData.nonfungiblePositionManager,
    legacyFarmingCenter,
    { ...feeData1 }
  )
  await farmingCenterV2.waitForDeployment()
  console.log('FarmingCenterV2 deployed to:', farmingCenterV2.target)

  const eternalFarming = await hre.ethers.getContractAt('IAlgebraEternalFarming', deploysData.eternal)
  const feeData2 = await getFeeData()
  await (await eternalFarming.setFarmingCenterAddress(farmingCenterV2.target, { ...feeData2 })).wait()
  console.log('Updated farming center address in eternal farming')

  const pluginFactory = await hre.ethers.getContractAt(BasePluginV1FactoryComplied.abi, deploysData.BasePluginV1Factory)
  const feeData3 = await getFeeData()
  await (await pluginFactory.setFarmingAddress(farmingCenterV2.target, { ...feeData3 })).wait()
  console.log('Updated farming center address in plugin factory')

  const posManager = await hre.ethers.getContractAt('INonfungiblePositionManager', deploysData.nonfungiblePositionManager)
  const feeData4 = await getFeeData()
  await (await posManager.setFarmingCenter(farmingCenterV2.target, { ...feeData4 })).wait()
  console.log('Updated farming center address in nonfungible position manager')

  if (deploysData.fc && deploysData.fc !== farmingCenterV2.target) {
    deploysData.fcV1 = deploysData.fc
  }
  deploysData.fc = farmingCenterV2.target
  deploysData.fcV2 = farmingCenterV2.target

  fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8')
  console.log('Saved updated addresses to:', deployDataPath)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
