const { ethers  } = require('hardhat');
const { gaugeFactoryV2Abi, gaugeFactoryV2Address } = require('./gaugeConstants/gauge-factory-v2');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    const gaugeContract = await ethers.getContractAt(gaugeFactoryV2Abi, gaugeFactoryV2Address);
    const getAllGauge = await gaugeContract.gauges();
    console.log("getAllGauge", getAllGauge)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });