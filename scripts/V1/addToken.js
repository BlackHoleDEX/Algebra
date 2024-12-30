const { ethers  } = require('hardhat');

async function main(){
    accounts = await ethers.getSigners();
    owner = accounts[0];
    console.log("selfAddress : ", owner.address);
    const selfAddress = owner.address;

    const TokenFactory = await ethers.getContractFactory("CustomToken");
    const initialSupply = ethers.utils.parseUnits("1000000", 18); // 1000000 * 10 ** 18 initial supply
    const token = await TokenFactory.deploy("MyToken2", "MTK2", initialSupply); 
    await token.deployed();
    console.log("Token deployed at:", token.address);
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
