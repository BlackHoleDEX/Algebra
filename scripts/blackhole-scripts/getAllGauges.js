const { ethers  } = require('hardhat');
const { voterV3Abi, voterV3Address } = require('../../generated/voter-v3');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    const gaugeContract = await ethers.getContractAt(voterV3Abi, voterV3Address);
    const getAllGauge = await gaugeContract.gauges("0x4Ef4897a47a9a98eeeb0235e1c8487ae87215CBb");
    console.log("getAllGauge", getAllGauge)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });