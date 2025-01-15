const { ethers } = require("hardhat")
const { permissionsRegistryAddress } = require("./gaugeConstants/permissions-registry")

async function main () {
    data = await ethers.getContractFactory("GaugeFactoryV2");
    input = [permissionsRegistryAddress]
    GaugeFactoryV2 = await upgrades.deployProxy(data, input, {initializer: 'initialize'});
    txDeployed = await GaugeFactoryV2.deployed();
    console.log('deployed GaugeFactoryV2: ', GaugeFactoryV2.address, txDeployed)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
