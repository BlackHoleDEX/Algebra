const tronbox = require('../tronbox-config');

const AlgebraEternalFarming = artifacts.require("AlgebraEternalFarming");
const FarmingCenter = artifacts.require("FarmingCenter");

const tronWeb = tronbox.tronWeb.nile

module.exports = async function(deployer) {

    const deployDataPath = path.resolve(__dirname, '../../../deploys.json')
    const deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'))

    deployer.deploy(AlgebraEternalFarming, deploysData.poolDeployer, deploysData.nonfungiblePositionManager).then(() => {
      console.log("AlgebraEternalFarming deployed to:", AlgebraEternalFarming.address)
    })
  
    deploysData.eternal = AlgebraEternalFarming.address;

    deployer.deploy(FarmingCenter, AlgebraEternalFarming.address, deploysData.nonfungiblePositionManager).then(() => {
      console.log("FarmingCenter deployed to:", FarmingCenter.address)
    })
  
    deploysData.fc = FarmingCenter.target;
    
    await AlgebraEternalFarming.setFarmingCenterAddress(FarmingCenter.address).send();
    console.log('Updated farming center address in eternal(incentive) farming')

    let pluginFactory = await tronWeb.contract().at(deploysData.BasePluginV1Factory);

    await pluginFactory.setFarmingAddress(FarmingCenter.target).send()
    console.log('Updated farming center address in plugin factory')
  
    let posManager = await tronWeb.contract().at(deploysData.nonfungiblePositionManager);
    await posManager.setFarmingCenter(FarmingCenter.target).send()
  
    fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8');
  }
}