const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

const jsonPath = path.resolve(__dirname, "../../token-constants/deployed-tokens.json");

const deployBlack = async () => {
    try {
        const blackContract = await ethers.getContractFactory("Black");
        const blackFactory = await blackContract.deploy();
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
    const blackAddress = await deployBlack();

    if (!blackAddress) {
        console.error("Failed to deploy Black token.");
        process.exit(1);
    }

    // Read the existing JSON file
    let deployedTokens = {};
    if (fs.existsSync(jsonPath)) {
        const fileData = fs.readFileSync(jsonPath, "utf8");
        deployedTokens = JSON.parse(fileData);
    }

    // Update or add the Black token address
    deployedTokens[0].address = blackAddress;

    // Write the updated JSON back to the file
    fs.writeFileSync(jsonPath, JSON.stringify(deployedTokens, null, 2));

    console.log("Updated deployed-tokens.json with Black token address!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Error in deployment:", error);
        process.exit(1);
    });
