const { ethers } = require("hardhat")
async function main () {
    data = await ethers.getContractFactory("GaugeFactoryV2");
    gaugeFactory = await data.deploy();
    txDeployed = await gaugeFactory.deployed();
    console.log("gaugeFactory: ", gaugeFactory.address)

    data = await ethers.getContractFactory("BribeFactoryV3");
    console.log('deploying...')
    BribeFactoryV2 = await upgrades.deployProxy(data,[owner.address, '0x0000000000000000000000000000000000000000'], {initializer: 'initialize'});
    txDeployed = await BribeFactoryV2.deployed();
    console.log('deployed b fact: ', BribeFactoryV2.address)
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
