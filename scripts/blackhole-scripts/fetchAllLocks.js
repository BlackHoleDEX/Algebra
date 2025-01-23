const { ethers  } = require('hardhat');
const { gaugeFactoryV2Abi, gaugeFactoryV2Address } = require('./gaugeConstants/gauge-factory-v2');
const { veNFTAPIAbi, veNFTAPIAddress } = require('./gaugeConstants/ve-nft-api');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    const veNFTApi = await ethers.getContractAt(veNFTAPIAbi, veNFTAPIAddress);
    const userLocks = await veNFTApi.getNFTFromAddress(owner.address);
    console.log("userLocks: ", userLocks)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });