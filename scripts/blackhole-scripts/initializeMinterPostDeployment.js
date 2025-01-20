const { ethers } = require("hardhat")
const { blackHolePairApiV2Abi, blackHolePairApiV2ProxyAddress } = require('./pairApiConstants');
const { minterUpgradableAddress, minterUpgradableAbi } = require('./gaugeConstants/minter-upgradable');
const { voterV3Address, voterV3Abi } = require("./gaugeConstants/voter-v3");
const { votingEscrowAddress, votingEscrowAbi } = require("./gaugeConstants/voting-escrow");
const { bribeAbi } = require("./gaugeConstants/bribe");
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");

// function _initialize(
//     address[] memory claimants,
//     uint[] memory amounts,
//     uint max // sum amounts / max = % ownership of top protocols, so if initial 20m is distributed, and target is 25% protocol ownership, then max - 4 x 20m = 80m
// ) external {

async function main () {
    const minter = await ethers.getContractAt(minterUpgradableAbi, minterUpgradableAddress);
    const initializingTx = await minter._initialize(
        [],
        [],
        0
    );
    await initializingTx.wait();
    console.log("Done initializing minter post deployment")

}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
