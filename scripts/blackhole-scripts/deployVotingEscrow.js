const { ethers } = require("hardhat")

async function main () {
    //need to deploy VeArtProxyUpgradeable first and the generated address need to pass in VotingEscrow
    data = await ethers.getContractFactory("VeArtProxyUpgradeable");
    veArtProxyUpgradeableFactory = await data.deploy();
    txDeployed = await veArtProxyUpgradeableFactory.deployed();
    console.log("veArtProxyUpgradeableFactory: ", veArtProxyUpgradeableFactory.address)

    //deployment of VotingEscrow
    data = await ethers.getContractFactory("VotingEscrow");
    votingEscrowFactory = await data.deploy("0x67ceA4391e5EeD4718237113CAE71B83F4AAF6e0", veArtProxyUpgradeableFactory.address);
    txDeployed = await votingEscrowFactory.deployed();
    console.log("VotingEscrowFactory: ", votingEscrowFactory.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
