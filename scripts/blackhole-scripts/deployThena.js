const { ethers } = require("hardhat")

async function main () {
    data = await ethers.getContractFactory("Thena");
    thenaFactory = await data.deploy();
    txDeployed = await thenaFactory.deployed();
    console.log("thenaFactory: ", thenaFactory.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
