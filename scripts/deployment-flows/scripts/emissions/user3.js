const { votingEscrowAbi, votingEscrowAddress } = require('../../../../generated/voting-escrow');
const { blackGovernorAbi, blackGovernorAddress } = require('../../../../generated/black-governor');
const { minterUpgradeableAbi, minterUpgradeableAddress } = require('../../../../generated/minter-upgradeable');
const { BigNumber } = require("ethers");


async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[2];
    const ownerAddress = owner.address;
    
    //create locks
    const votingEscrowContract = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);
    const lockAmount3 = BigNumber.from(1500).mul(BigNumber.from("1000000000000000000"));
    await votingEscrowContract.create_lock(lockAmount3, 126144000, false);

    //Epoch 2
    //delegate votes of user3 to user 2
    votingEscrowContract.delegates("0xa7243fc6FB83b0490eBe957941a339be4Db11c29");
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});