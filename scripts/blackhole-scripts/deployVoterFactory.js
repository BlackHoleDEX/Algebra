const { ethers } = require("hardhat")

async function main () {
    data = await ethers.getContractFactory("VoterV3");
    voterFactory = await data.deploy();
    txDeployed = await voterFactory.deployed();
    console.log("voterFactory: ", voterFactory.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
