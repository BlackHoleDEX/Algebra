const { ethers } = require("hardhat")
const { voterV3Address } = require("../../generated/voter-v3");
const { votingEscrowAddress } = require("../../generated/voting-escrow");
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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
