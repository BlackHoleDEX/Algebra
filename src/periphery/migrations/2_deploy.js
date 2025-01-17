const { artifacts } = require('hardhat');
const tronbox = require('../tronbox-config');

const AlgebraCustomPoolEntryPoint = artifacts.require("AlgebraCustomPoolEntryPoint");
const TickLens = artifacts.require("TickLens");
const Quoter = artifacts.require('Quoter');
const SwapRouter = artifacts.require('SwapRouter');
const QuoterV2 = artifacts.require('QuoterV2');
const NFTDescriptor = artifacts.require('NFTDescriptor')
const Proxy = artifacts.require('TransparentUpgradeableProxy')
const NonfungibleTokenPositionDescriptor = artifacts.require('NonfungibleTokenPositionDescriptor')
const NonfungiblePositionManager = artifacts.require('NonfungiblePositionManager')
const AlgebraInterfaceMulticall = artifacts.require('AlgebraInterfaceMulticall');

const deployerAddress = "TGq5GWxruUu47FaTcHLiX8oJGNtD8aRcoV"
const tronWeb = tronbox.tronWeb.nile

module.exports = async function(deployer) {
    const deployDataPath = path.resolve(__dirname, '../../../deploys.json');
    let deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));
  
    // WNativeTokenAddress
    const WNativeTokenAddress = 'TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR';
  
    deploysData.wrapped = WNativeTokenAddress;

    deployer.deploy(AlgebraCustomPoolEntryPoint, deploysData.factory).then(() => {
      console.log("AlgebraCustomPoolEntryPoint deployed to:", AlgebraCustomPoolEntryPoint.address)
    })
  
    deploysData.entryPoint = AlgebraCustomPoolEntryPoint.address
    console.log('EntryPoint deployed to:', AlgebraCustomPoolEntryPoint.address)
  
    const factory = await tronWeb.contract().at(deploysData.factory);
    
    await factory.grantRole("0xc9cf812513d9983585eb40fcfe6fd49fbb6a45815663ec33b30a6c6c7de3683b", AlgebraCustomPoolEntryPoint.address).send();
    await factory.grantRole("0xb73ce166ead2f8e9add217713a7989e4edfba9625f71dfd2516204bb67ad3442", AlgebraCustomPoolEntryPoint.address).send();
  
    await deployer.deploy(TickLens)
    deploysData.tickLens = TickLens.address;
    console.log('TickLens deployed to:', TickLens.address);
  
    deployer.deploy(Quoter, deploysData.factory, WNativeTokenAddress, deploysData.poolDeployer).then(() => {
      console.log("Quoter deployed to:", Quoter.address)
    })
    deploysData.quoter = Quoter.address;

    deployer.deploy(QuoterV2, deploysData.factory, WNativeTokenAddress, deploysData.poolDeployer).then(() => {
      console.log("QuoterV2 deployed to:", QuoterV2.address)
    })
    deploysData.quoterV2 = QuoterV2.address;
  
    deployer.deploy(SwapRouter, deploysData.factory, WNativeTokenAddress, deploysData.poolDeployer).then(() => {
      console.log("SwapRouter deployed to:", SwapRouter.address)
    })
    deploysData.swapRouter = SwapRouter.address;
  
    await deployer.deploy(NFTDescriptor)
    deploysData.NFTDescriptor = NFTDescriptor.address;
    console.log('NFTDescriptor deployed to:', NFTDescriptor.address);
    
    await deployer.link(NFTDescriptor, NonfungibleTokenPositionDescriptor);
    deployer.deploy(NonfungibleTokenPositionDescriptor, WNativeTokenAddress, 'TRON', []).then(() => {
      console.log("NonfungibleTokenPositionDescriptor deployed to:", NonfungibleTokenPositionDescriptor.address)
    })
    deploysData.NonfungibleTokenPositionDescriptor = NonfungibleTokenPositionDescriptor.address;

    deployer.deploy(Proxy, NonfungibleTokenPositionDescriptor.address, deployerAddress, '0x').then(() => {
      console.log("Proxy deployed to:", Proxy.address)
    })
    deploysData.proxy = Proxy.address;

    deployer.deploy(NonfungiblePositionManager, deploysData.factory, WNativeTokenAddress, Proxy.address, deploysData.poolDeployer).then(() => {
      console.log("NonfungiblePositionManager deployed to:", NonfungiblePositionManager.address)
    })
    deploysData.nonfungiblePositionManager = NonfungiblePositionManager.address;

    await deployer.deploy(AlgebraInterfaceMulticall)
    console.log('AlgebraInterfaceMulticall deployed to:', AlgebraInterfaceMulticall.address);
  
    fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8');
}