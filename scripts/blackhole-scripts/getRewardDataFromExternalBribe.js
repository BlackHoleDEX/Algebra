const { ethers  } = require('hardhat');
const { gaugeFactoryV2Abi, gaugeFactoryV2Address } = require('./gaugeConstants/gauge-factory-v2');
// const { routerV2Address } = require('./gaugeConstants/')
const { gaugeV2Abi } = require('./gaugeConstants/gaugeV2-constants');
const { votingEscrowAbi } = require('./gaugeConstants/voting-escrow');
const { minterUpgradableAbi } = require('./gaugeConstants/minter-upgradable');
const { bribeAbi } = require('./gaugeConstants/bribe')
const { tokenThree, tokenFour, tokenOne, tokenAbi } = require("../V1/dexAbi");
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { BigNumber } = require("ethers");

async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    const gaugeFactoryContract = await ethers.getContractAt(gaugeFactoryV2Abi, gaugeFactoryV2Address);
    const getAllGauge = await gaugeFactoryContract.gauges();
    for(const gauge of getAllGauge){
        if(gauge === ZERO_ADDRESS)
            continue;

        const gaugeV2Contract = await ethers.getContractAt(gaugeV2Abi, gauge);
        const ExternalBribeAddress = await gaugeV2Contract.external_bribe();
        const ExternalBribeContract = await ethers.getContractAt(bribeAbi, ExternalBribeAddress);

        const votingEscrowContract = await ethers.getContractAt(votingEscrowAbi, "0x7351A464aaa5A90378fd608d967E2A152251dE32");
        const owner = await votingEscrowContract.ownerOf("1");
        console.log("owner", owner)


        // const MinterUpgradableContract = await ethers.getContractAt(minterUpgradableAbi, "0xcE9F683915B591c19529Bb82bE302ccFfcf69c95");
        // const activeP = await MinterUpgradableContract.active_period();
        // const epochTime = await ExternalBribeContract.getEpochStart();
        // const epochTimeNumber = Number(epochTime); // Convert the string to a number
        // const updatedEpochTime = epochTimeNumber + 1800; // Add 1800
        // const balance = await ExternalBribeContract.balanceOf(tokenThree);
        // console.log("externalBribeAddress ", ExternalBribeContract.address, balance)
        // const rewradData = await ExternalBribeContract.rewardData(tokenThree, updatedEpochTime);
        // const userTimeStamp = await ExternalBribeContract.userTimestamp(tokenThree, updatedEpochTime);
        
        // console.log("epoch and reward data", activeP, updatedEpochTime, rewradData)
    }
    console.log("getAllGauge", getAllGauge)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });