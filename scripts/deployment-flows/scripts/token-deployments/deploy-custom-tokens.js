const tokens = require("../../token-constants/deploying-tokens.json");
const { ethers } = require("hardhat")
const fs = require("fs");

async function main() {
    const customTokenContract = await ethers.getContractFactory("CustomToken");
    const millionTokens = "1000000000000000000000000000000000"
    console.log("custom token contrac", customTokenContract);
    tokens.forEach(async (token) => {
        const deployingCustomToken = await customTokenContract.deploy(token.name, token.ticker, millionTokens);
        const deployedToken = await deployingCustomToken.deployed();
        // string memory name_,
        // string memory symbol_,
        // uint256 initialSupply_

        console.log(`Deployed ${token.name} at address: ${deployedToken.address}`);

        // Add the deployed address to the token object
        tokens[i].address = deployedToken.address;

        // Save the updated JSON with deployed addresses
        fs.writeFileSync(jsonPath, JSON.stringify({ tokens }, null, 2));

        console.log("Updated deploying-tokens.json with deployed addresses!");
    })
}

main()
.then(() => console.log("Done deploying cusotm tokens"))
.catch((errr) => console.log("Error in deploying custom token", err))
