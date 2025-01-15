const { ethers  } = require('hardhat');

const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { blackHolePairApiV2Abi, blackHolePairApiV2ProxyAddress } = require('./pairApiConstants');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    const blackHoleAllPairContract = await ethers.getContractAt(blackHolePairApiV2Abi, blackHolePairApiV2ProxyAddress);
    const blackHoleAllPairContractOwner = await blackHoleAllPairContract.owner();
    console.log("blackHoleAllPairContract owner : ", blackHoleAllPairContractOwner);

    const  blackHoleAllPairContractPairsData = await blackHoleAllPairContract.getAllPair(owner.address, BigInt(1), BigInt(0));
    const totalPairs = blackHoleAllPairContractPairsData[0];
    const pairs = blackHoleAllPairContractPairsData[1];
    console.log("Total pairs : ", totalPairs);
    console.log("All pairs : ", pairs);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });