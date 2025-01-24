const { ethers  } = require('hardhat');
const { gaugeFactoryV2Abi, gaugeFactoryV2Address } = require('./gaugeConstants/gauge-factory-v2');
const { gaugeV2Abi } = require('./gaugeConstants/gaugeV2-constants');
const { bribeAbi } = require('./gaugeConstants/bribe')
const { tokenThree, tokenFour } = require("../V1/dexAbi");
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { BigNumber } = require("ethers");

async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    const gaugeFactoryContract = await ethers.getContractAt(gaugeFactoryV2Abi, gaugeFactoryV2Address);
    const getAllGauge = await gaugeFactoryContract.gauges();
    for(const gauge of getAllGauge){
        // console.log("gauge", gauge)
        if(gauge === ZERO_ADDRESS)
            continue;

        const gaugeV2Contract = await ethers.getContractAt(gaugeV2Abi, gauge);
        console.log("added bribe to 1")
        const ExternalBribeAddress = await gaugeV2Contract.external_bribe();
        console.log("added bribe to 2")

        const ExternalBribeContract = await ethers.getContractAt(bribeAbi, ExternalBribeAddress);
        console.log("added bribe to 3")


        const bribeAmount = BigNumber.from("10000").mul(BigNumber.from("1000000000000000000"));
        await ExternalBribeContract.notifyRewardAmount(tokenThree, bribeAmount);
        console.log("added bribe to 4")

    }
    console.log("getAllGauge", getAllGauge)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });