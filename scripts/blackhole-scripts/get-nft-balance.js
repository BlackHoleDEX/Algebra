const { BigNumber } = require("ethers");
const { votingEscrowAbi, votingEscrowAddress } = require("./gaugeConstants/voting-escrow")

async function main () {
    const votingEscrow = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);
    const balanceOfNFT = await votingEscrow.balanceOfNFT(BigNumber.from(1).multipliedBy(1e18));
    console.log('balance of nft: ', balanceOfNFT);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
