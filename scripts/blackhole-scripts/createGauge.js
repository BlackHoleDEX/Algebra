async function main () {

}const { ethers  } = require('hardhat');

const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { blackHoleAllPairAbi, blackHoleAllPairProxyAddress } = require('./pairApiConstants');
const { voterV3Abi, voterV3Address } = require('./abhijeet-new-constants/voter-v3');

async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]
    const ownerAddress = owner.address;

    const voterV3Contract = await ethers.getContractAt(voterV3Abi, voterV3Address);
    console.log("voterV3Contract ", voterV3Address, voterV3Contract.address)

    // creating gauge for pair bwn - token one and token two - basic volatile pool
    const pairAddressTrial = "0x1c2b9eb0a6c13e7d21f9915bea738e4d7a24c358";

    const createGaugeTx = await voterV3Contract.createGauge(pairAddressTrial, BigInt(0), {
        gasLimit: 21000000
    });
    console.log('createdgaugetx', createGaugeTx);
    await createGaugeTx.wait();

    console.log('done creation of gauge tx')
}   

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});