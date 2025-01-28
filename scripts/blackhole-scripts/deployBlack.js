const { ethers } = require("hardhat")

async function main () {
    data = await ethers.getContractFactory("Black");
    blackFactory = await data.deploy();
    txDeployed = await blackFactory.deployed();
    console.log("blackFactory: ", blackFactory.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
