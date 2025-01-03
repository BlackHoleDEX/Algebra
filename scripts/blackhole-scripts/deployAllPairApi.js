const { ethers  } = require('hardhat');

const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { pairFactoryAddress } = require("../V1/dexAbi");



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    data = await ethers.getContractFactory("BlackHolePairAPI");
    const blackHolePairAPIFactory = await upgrades.deployProxy(data, [pairFactoryAddress], {initializer: 'initialize'});
    await blackHolePairAPIFactory.deployed();
    console.log("BlackHolePairAPIFactory : ", blackHolePairAPIFactory.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
