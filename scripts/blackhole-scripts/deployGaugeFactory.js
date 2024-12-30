const { ethers } = require("hardhat")

async function main () {
    data = await ethers.getContractFactory("GaugeFactoryV2");
    gaugeFactory = await data.deploy();
    txDeployed = await gaugeFactory.deployed();
    console.log("gaugeFactory: ", gaugeFactory.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
