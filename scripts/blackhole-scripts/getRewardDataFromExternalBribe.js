const { ethers  } = require('hardhat');
const { gaugeFactoryV2Abi, gaugeFactoryV2Address } = require('./gaugeConstants/gauge-factory-v2');
// const { routerV2Address } = require('./gaugeConstants/')
const { gaugeV2Abi } = require('./gaugeConstants/gaugeV2-constants');
const { votingEscrowAbi } = require('./gaugeConstants/voting-escrow');
const { minterUpgradableAbi } = require('./gaugeConstants/minter-upgradable');
const { thenaAbi, thenaAddress } = require('./gaugeConstants/thena');
const { bribeAbi } = require('./gaugeConstants/bribe')
const { tokenThree, tokenFour, tokenOne, tokenAbi, tokenTwo } = require("../V1/dexAbi");
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
        const ExternalBribeAddress = await gaugeV2Contract.internal_bribe();
        const ExternalBribeContract = await ethers.getContractAt(bribeAbi, ExternalBribeAddress);
        // console.log("bribeAddress", ExternalBribeAddress);

        // const votingEscrowContract = await ethers.getContractAt(votingEscrowAbi, "0x7351A464aaa5A90378fd608d967E2A152251dE32");
        // const owner = await votingEscrowContract.ownerOf("1");
        // console.log("owner", owner)


        // const MinterUpgradableContract = await ethers.getContractAt(minterUpgradableAbi, "0xcE9F683915B591c19529Bb82bE302ccFfcf69c95");
        // const activeP = await MinterUpgradableContract.balanceOf("0x1471A7a6F5a9b9AF8F2A88dbc798693D3C1ff8BD");
        // console.log("balance ", activeP);


        /*  check balance of thena for minterupgradable  */
        // const ThenaContract = await ethers.getContractAt(thenaAbi, thenaAddress);
        // const activeP = await ThenaContract.balanceOf("0xcE9F683915B591c19529Bb82bE302ccFfcf69c95");
        // console.log("balance ", activeP);


        // const epochTime = await ExternalBribeContract.getEpochStart();
        // const epochTimeNumber = Number(epochTime); // Convert the string to a number
        // const updatedEpochTime = epochTimeNumber; // Add 1800
        // const balance = await ExternalBribeContract.balanceOf(tokenOne);
        // console.log("externalBribeAddress ", ExternalBribeContract.address, balance, updatedEpochTime);
        // // for(let i = updatedEpochTime-5400;i<=updatedEpochTime+5400;i+=1800){
        //   const rewradData1 = await ExternalBribeContract.rewardData(tokenOne, epochTimeNumber);
        //   const rewradData2 = await ExternalBribeContract.rewardData(tokenTwo, epochTimeNumber);
        //   console.log("rewadData1 ", rewradData, "rewardData2 ", rewradData2)
        // }
        



        // for(let i=1738045800-5400;i<=1738045800+5400;i+=1800){
        //   const rewadData = await ExternalBribeContract.rewardData(tokenOne, i);
        //   if(rewadData.rewardsPerEpoch != 0)
        //   {
        //     console.log("rewadData ", i, rewadData)
        //   }
        // }
        // const userTimeStamp = await ExternalBribeContract.userTimestamp(tokenThree, updatedEpochTime);
        
        // console.log("epoch and reward data", activeP, updatedEpochTime, rewradData)
        const earnedAmount = await ExternalBribeContract.earned(BigNumber.from("1"), tokenOne);
        console.log("earnedAmount ", earnedAmount);
      }
    console.log("getAllGauge", getAllGauge)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });