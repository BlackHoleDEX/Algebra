const { ethers } = require("hardhat")
const { thenaAddress } = require('./gaugeConstants/thena');
const { VeArtProxyUpgradeableAddress } = require('./gaugeConstants/ve-art-proxy-upgradeable')

async function main () {
    //need to deploy VeArtProxyUpgradeable first and the generated address need to pass in VotingEscrow
    // data = await ethers.getContractFactory("VeArtProxyUpgradeable");
    // veArtProxyUpgradeableFactory = await upgrades.deployProxy(data,[], {initializer: 'initialize'});
    // txDeployed = await veArtProxyUpgradeableFactory.deployed();
    // console.log('veArtProxyUpgradeableFactory ', veArtProxyUpgradeableFactory.address)

    //deployment of VotingEscrow
    data = await ethers.getContractFactory("VotingEscrow");
    const votingEscrow = await data.deploy(thenaAddress, VeArtProxyUpgradeableAddress);
    txDeployed = await votingEscrow.deployed();
    console.log('votingEscrow ', votingEscrow.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
