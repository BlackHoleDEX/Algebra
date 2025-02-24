const { ethers } = require("hardhat")
const { voterV3Address, voterV3Abi } = require("../../generated/voter-v3");
const { votingEscrowAddress, votingEscrowAbi } = require("../../generated/voting-escrow");
const { minterUpgradeableAddress } = require("../../generated/minter-upgradeable");

async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0] 
    data = await ethers.getContractFactory("AutomatedVotingManager");
    console.log('deploying AVM...')
    input = [voterV3Address,
        votingEscrowAddress,
        // chainlinkExecutorAddress,
        owner.address,
        minterUpgradeableAddress]
    avmContract = await upgrades.deployProxy(data, input, {initializer: 'initialize'});
    txDeployed = await avmContract.deployed();
    console.log('deployed AVM v3: ', avmContract.address)
    const votingEscrow = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);
    const settingAVM = await votingEscrow.setAVM(avmContract.address);
    await settingAVM.wait();
    const voter = await ethers.getContractAt(voterV3Abi, voterV3Address);
    const settingAVMInVoter = await voter.setAVM();
    await settingAVMInVoter.wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
