const { ethers  } = require('hardhat');

const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { blackHolePairApiV2Abi, blackHolePairApiV2ProxyAddress } = require('./pairApiConstants');
const { pairFactoryAbi, pairFactoryAddress } = require('../V1/dexAbi');
const { voterV3Abi, voterV3Address } = require('./gaugeConstants/voter-v3');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    const voterV3Contract = await ethers.getContractAt(voterV3Abi, voterV3Address);
    console.log("voterV3Contract ", voterV3Address, voterV3Contract.address);
    console.log("voterV3: ", await voterV3Contract._epochTimestamp());

    const pairFactoryContract = await ethers.getContractAt(pairFactoryAbi, pairFactoryAddress);
    const pairsLength = await pairFactoryContract.allPairsLength();

    console.log("pairsLength : ", pairsLength);

    const blackHoleAllPairContract = await ethers.getContractAt(blackHolePairApiV2Abi, blackHolePairApiV2ProxyAddress);
    const blackHoleAllPairContractOwner = await blackHoleAllPairContract.owner();
    console.log("blackHoleAllPairContract owner : ", blackHoleAllPairContractOwner);
    console.log('get all pair inputs', owner.address, BigInt(pairsLength), BigInt(0))
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