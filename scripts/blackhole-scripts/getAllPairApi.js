const { ethers  } = require('hardhat');

const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { blackHolePairApiV2Abi, blackHolePairApiV2ProxyAddress } = require('./pairApiConstants');
const { pairFactoryAbi, pairFactoryAddress } = require('../V1/dexAbi');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    const pairFactoryContract = await ethers.getContractAt(pairFactoryAbi, pairFactoryAddress);
    const pairsLength = await pairFactoryContract.allPairsLength();

    console.log("pairsLength : ", pairsLength);

    const blackHoleAllPairContract = await ethers.getContractAt(blackHolePairApiV2Abi, blackHolePairApiV2ProxyAddress);
    const blackHoleAllPairContractOwner = await blackHoleAllPairContract.owner();
    console.log("blackHoleAllPairContract owner : ", blackHoleAllPairContractOwner);

    const  blackHoleAllPairContractPairsData = await blackHoleAllPairContract.getAllPair(owner.address, BigInt(pairsLength), BigInt(0));
    // const totalPairs = blackHoleAllPairContractPairsData[0];
    // const pairs = blackHoleAllPairContractPairsData[1];
    // console.log("Total pairs : ", totalPairs);
    console.log("All pairs : ", blackHoleAllPairContractPairsData);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });