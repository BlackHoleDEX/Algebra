const { ethers } = require("hardhat")
const { votingEscrowAddress } = require('./abhijeet-new-constants/voting-escrow')
const { gaugeFactoryV2Address } = require('./abhijeet-new-constants/gauge-factory-v2')
const { bribeFactoryV3Address } = require('./abhijeet-new-constants/bribe-factory-v3')
const { pairFactoryAddress } = require("../V1/dexAbi");

async function main () {
    data = await ethers.getContractFactory("VoterV3");
    // function initialize(address __ve, address _pairFactory, address  _gaugeFactory, address _bribes) initializer public {
    inputs = [votingEscrowAddress, pairFactoryAddress , gaugeFactoryV2Address, bribeFactoryV3Address]
    VoterV3 = await upgrades.deployProxy(data, inputs, {initializer: 'initialize'});
    txDeployed = await VoterV3.deployed();
    console.log('VoterV3.address: ', VoterV3.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
