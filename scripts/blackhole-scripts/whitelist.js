const { blackAddress } = require("../../generated/black");
const { tokenHandlerAbi, tokenHandlerAddress } = require("../../generated/token-handler");
const deployedTokens = require("../deployment-flows/token-constants/deploying-tokens.json")
async function main () {
    const tokenHandler = await ethers.getContractAt(tokenHandlerAbi, tokenHandlerAddress);
    const allTokens = deployedTokens.map(elm => elm.address);
    console.log("all tokens:", allTokens)
    const whitelistedTokens = await tokenHandler.whiteListedTokens();
    console.log("whitelisted tokens: ", whitelistedTokens);
    for(let i=0; i<allTokens.length; i++) {
        if(!whitelistedTokens.includes(allTokens[i])) {
            const whitelistTx = await tokenHandler.whitelistTokens([...allTokens, blackAddress]);
            await whitelistTx.wait();
            console.log("done whitelisting! for token addresS: ", allTokens.address)
        }
    }
    
const connectors = [blackAddress, "0x036CbD53842c5426634e7929541eC2318f3dCF7e", "0x4200000000000000000000000000000000000006", "0x6b4E87449d88121772bc9BeE1E653c77a16aA522", "0xCe936Fa3b745c63112f3d31CbD68c06A415F3B53", "0xC49B97B66576fe2381439198fca0d189C41562b5"]
    const connectorTx = await tokenHandler.whitelistConnectors(connectors);
    await connectorTx.wait();
    console.log("all tokens: ", allTokens)
}

main().then(() => console.log("Done!"))
