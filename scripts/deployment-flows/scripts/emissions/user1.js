const { votingEscrowAbi, votingEscrowAddress } = require('../../../../generated/voting-escrow');
const { blackGovernorAbi, blackGovernorAddress } = require('../../../../generated/black-governor');
const { minterUpgradeableAbi, minterUpgradeableAddress } = require('../../../../generated/minter-upgradeable');
const { BigNumber } = require("ethers");
const { blackAbi } = require('../../../../generated/black');
// const { blackAddress } = require('../../token-constants/deployed-tokens.json');


async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0];
    const ownerAddress = owner.address;
    
    //Epoch 0: create locks for user 1
    const votingEscrowContract = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);
    // const lockAmount1 = BigNumber.from(2000).mul(BigNumber.from("1000000000000000000"));
    // try {
    //   const black = await ethers.getContractAt(blackAbi, "0xe1503B776047505eb6CdAc2166D016025D83E0b7");
    //   const approvaltx = await black.approve(votingEscrowAddress, "2000000000000000000000");
    //   const createLocktx = await votingEscrowContract.create_lock("2000000000000000000000", "126144000", false);
    // } catch (error) {
    //   console.log("error in voting", error)
    // }

    const minterContract = await ethers.getContractAt(minterUpgradeableAbi, minterUpgradeableAddress);
    const blackGovernorContract = await ethers.getContractAt(blackGovernorAbi, blackGovernorAddress);

    // try {
    //   const calldata = minterContract.interface.encodeFunctionData("nudge");
    //   const pid = await blackGovernorContract.propose([minterUpgradeableAddress], [0], [calldata]);
    //   console.log("pid ", pid);
    // } catch (error) {
    //   console.log("error in blackGovernorContract ", error)
    // }

    await blackGovernorContract.castVote("16134786894693074512526881837070247251028559825807118338989515965967069897879", 1);

    // //Epoch 1: execute
    // const epochHash = await blackGovernorContract.epochStarts();
    // await blackGovernorContract.execute([minterUpgradeableAddress], [0], [calldata], epochHash);    
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});