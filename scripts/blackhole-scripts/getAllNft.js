const { ethers  } = require('hardhat');
const { votingEscrowAbi, votingEscrowAddress } = require('../../generated/voting-escrow');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0];

    const voterContract = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);
    const getAllGauge = await voterContract.locked(2);
    console.log("getAllGauge", getAllGauge)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });