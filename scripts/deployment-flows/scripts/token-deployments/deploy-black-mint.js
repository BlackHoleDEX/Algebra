const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const deployedTokensPath = path.resolve(__dirname, "../../token-constants/deployed-tokens.json");
const deployedTokens = require(deployedTokensPath);

const deployBlack = async (receiver, amount) => {
    try {
        const blackContract = await ethers.getContractFactory("Black");

        const amountAdd = BigNumber.from(amount).mul(BigNumber.from("1000000000000000000"));

        const blackFactory = await blackContract.deploy(receiver, amountAdd);
        await blackFactory.deployed();
        console.log("Black token deployed at:", blackFactory.address);
        return blackFactory.address;
    } catch (error) {
        console.log("Error deploying Black:", error);
    }
};

async function main() {
    const accounts = await ethers.getSigners();
    const owner = accounts[0];

    // Deploy Black token
    const blackAddress = await deployBlack(owner.address, 10000);

    if (!blackAddress) {
        console.error("Failed to deploy Black token.");
        process.exit(1);
    }

    // Update or add the Black token address
    deployedTokens[0].address = blackAddress;

    console.log("deployedTokens" , deployedTokensPath, JSON.stringify(deployedTokens, null, 2));

    // Write the updated JSON back to the file
    fs.writeFileSync(deployedTokensPath, JSON.stringify(deployedTokens, null, 2));

    console.log("Updated deployed-tokens.json with Black token address!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Error in deployment:", error);
        process.exit(1);
    });
