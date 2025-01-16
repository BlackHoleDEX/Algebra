const { ethers } = require("hardhat")
const { rewardsDistributorAbi, rewardsDistributorAddress } = require("./gaugeConstants/reward-distributor");
const { votingEscrowAddress } = require('./gaugeConstants/voting-escrow');
const { voterV3Address, voterV3Abi } = require("./gaugeConstants/voter-v3");

async function main () {

    data = await ethers.getContractFactory("MinterUpgradeable");
    inputs = [voterV3Address, votingEscrowAddress, rewardsDistributorAddress]
    console.log('deploying...', inputs)
    const minterUpgradeable = await upgrades.deployProxy(data, inputs, {initializer: 'initialize'});
    txDeployed = await minterUpgradeable.deployed();
    console.log('minterUpgradeable : ', minterUpgradeable.address)

    const voterV3Contract = await ethers.getContractAt(voterV3Abi, voterV3Address);
    console.log("voterV3: ", await voterV3Contract.setMinter(minterUpgradeable.address));
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
