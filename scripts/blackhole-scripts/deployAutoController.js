const { ethers } = require("hardhat")

async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]
    const data = await ethers.getContractFactory("AutoCtr");
    const AutoControllerContract = await data.deploy();
    txDeployed = await AutoControllerContract.deployed();
    console.log("AutoControllerContract Address: ", AutoControllerContract.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
