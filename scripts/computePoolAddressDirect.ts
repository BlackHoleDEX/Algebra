import { ethers } from "ethers";

// Constants
const POOL_INIT_CODE_HASH = "0xae009e914d7367e9d6b71fe6f2d0e739a50b5055a96ae6f46f15a901de70af5c";

function computePoolAddress(
    poolDeployer: string,
    customDeployer: string,
    tokenA: string,
    tokenB: string
): string {
    // Ensure addresses are checksummed
    poolDeployer = ethers.utils.getAddress(poolDeployer);
    customDeployer = ethers.utils.getAddress(customDeployer);
    tokenA = ethers.utils.getAddress(tokenA);
    tokenB = ethers.utils.getAddress(tokenB);

    // Sort tokens (token0 must be less than token1)
    let [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() 
        ? [tokenA, tokenB] 
        : [tokenB, tokenA];

    // Create the inner hash based on whether there's a custom deployer
    const innerHash = customDeployer === ethers.constants.AddressZero
        ? ethers.utils.defaultAbiCoder.encode(['address', 'address'], [token0, token1])
        : ethers.utils.defaultAbiCoder.encode(['address', 'address', 'address'], [customDeployer, token0, token1]);

    // Compute the pool address using the same logic as the Solidity contract
    const salt = ethers.utils.keccak256(innerHash);
    
    const poolAddress = ethers.utils.getCreate2Address(
        poolDeployer,
        salt,
        POOL_INIT_CODE_HASH
    );

    return poolAddress;
}

async function main() {
    // Example addresses (replace with your actual addresses)
    const poolDeployer = "0x1234567890123456789012345678901234567890";
    const customDeployer = "0x2345678901234567890123456789012345678901"; // use ethers.constants.AddressZero for no custom deployer
    const tokenA = "0x3456789012345678901234567890123456789012";
    const tokenB = "0x4567890123456789012345678901234567890123";

    console.log("\nInput Parameters:");
    console.log("Pool Deployer:", poolDeployer);
    console.log("Custom Deployer:", customDeployer);
    console.log("Token A:", tokenA);
    console.log("Token B:", tokenB);

    // Validation
    console.log("\nValidation:");
    console.log("Token A < Token B:", tokenA.toLowerCase() < tokenB.toLowerCase());
    
    try {
        const poolAddress = computePoolAddress(
            poolDeployer,
            customDeployer,
            tokenA,
            tokenB
        );
        
        console.log("\nComputed Pool Address:", poolAddress);

        // If you want to try without custom deployer
        const standardPoolAddress = computePoolAddress(
            poolDeployer,
            ethers.constants.AddressZero,
            tokenA,
            tokenB
        );
        
        console.log("Computed Standard Pool Address (no custom deployer):", standardPoolAddress);

    } catch (error) {
        console.error("\nError computing pool address:", error.message);
    }
}

// Execute the script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Script failed:", error);
        process.exit(1);
    }); 