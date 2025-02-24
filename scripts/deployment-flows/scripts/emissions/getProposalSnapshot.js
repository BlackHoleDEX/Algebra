const { votingEscrowAbi, votingEscrowAddress } = require('../../../../generated/voting-escrow');
const { blackGovernorAbi, blackGovernorAddress } = require('../../../../generated/black-governor');


async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0];
    const ownerAddress = owner.address;
    
    const blackGovernorContract = await ethers.getContractAt(blackGovernorAbi, blackGovernorAddress);
    const votingEscrowContract = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);

    const xx = await votingEscrowContract.getPastTotalSupply("1740404702"); //assign pid
    console.log("statue of pid ", xx)


    const snapshot = await blackGovernorContract.proposalSnapshot("16134786894693074512526881837070247251028559825807118338989515965967069897879");
    // const statusPid = await blackGovernorContract.quorum(snapshot); //assign pid


    // const votes = await blackGovernorContract._proposalVotes("16134786894693074512526881837070247251028559825807118338989515965967069897879"); 

    console.log("statue of pid ", snapshot)
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});