const { ethers } = require("hardhat");
const { voterV3Abi, voterV3Address } = require("../../../../generated/voter-v3");
const { votingEscrowAbi, votingEscrowAddress } = require("../../../../generated/voting-escrow")
const { veNFTAPIAbi, veNFTAPIAddress } = require("../../../../generated/ve-nftapi")
const { blackAbi } = require("../../../blackhole-scripts/gaugeConstants/black")
const deployedTokens = require("../../token-constants/deployed-tokens.json")
const blackAddress = deployedTokens[0].address
console.log("BLACK ADDRESS IS: ", blackAddress)
async function main() {
    accounts = await ethers.getSigners();

    // console.log("accoutns: ", accounts[1])

    const voterV3Contract = await ethers.getContractAt(voterV3Abi, voterV3Address)
    const votingEscrowContract = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);

    const veNftApiContract = await ethers.getContractAt(veNFTAPIAbi, veNFTAPIAddress);

    const blackContract = await ethers.getContractAt(blackAbi, blackAddress);
    console.log("user black balance", await blackContract.balanceOf(accounts[0].address))
    // const blackApprovalTx = await blackContract.approve(votingEscrowAddress, 
    //     "10000000000"
    // )
    // await blackApprovalTx.wait() // dont need to wait prolly due to some queueing mechanism, queueing spelling might be wrong lol
    // const periodLocking = 86400*7*52 // 1 year
    // const lockCreated = await votingEscrowContract.create_lock(10, periodLocking)
    // await lockCreated.wait()

    const nftIds = await veNftApiContract.getNFTFromAddress(accounts[0].address);
    console.log("nft ids are before poking: ", nftIds);

    console.log("last voter for an id that has never voted", await voterV3Contract.lastVoted(3));
    // ids from 1 to 3 belong to this user
    // try increasing for the token id 1
    const approveTokenIDForVotingEscrow = await votingEscrowContract.approve(votingEscrowAddress, 2);
    await approveTokenIDForVotingEscrow.wait()
    const increaseLockedAmountTx = await votingEscrowContract.increase_amount(2, 1000);
    await increaseLockedAmountTx.wait()

    const nftIdsPostPoke = await veNftApiContract.getNFTFromAddress(accounts[0].address);
    console.log("nft idsafter poking are: ", nftIdsPostPoke);
    // getNFTFromAddress
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});