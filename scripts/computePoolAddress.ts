import { ethers } from "hardhat";

async function main() {
    // Deploy the PoolAddressTest contract
    const PoolAddressTest = await ethers.getContractFactory("PoolAddressTest");
    const poolAddressTest = await PoolAddressTest.deploy();
    await poolAddressTest.deployed();

    console.log("PoolAddressTest deployed to:", poolAddressTest.address);

    // Example addresses (replace these with your actual addresses)
    const poolDeployer = "0x1234567890123456789012345678901234567890";
    const customDeployer = "0x2345678901234567890123456789012345678901";
    const tokenA = "0x3456789012345678901234567890123456789012";
    const tokenB = "0x4567890123456789012345678901234567890123";

    // Validate token ordering
    console.log("\nToken addresses:");
    console.log("Token A:", tokenA);
    console.log("Token B:", tokenB);
    console.log("Token A < Token B:", BigInt(tokenA) < BigInt(tokenB));

    try {
        // Compute pool address with custom deployer
        console.log("\nAttempting to compute pool address with custom deployer...");
        console.log("Pool Deployer:", poolDeployer);
        console.log("Custom Deployer:", customDeployer);
        
        const poolAddress = await poolAddressTest.computePoolAddress(
            poolDeployer,
            customDeployer,
            tokenA,
            tokenB
        );
        console.log("Success! Pool address with custom deployer:", poolAddress);

        // Compute standard pool address (without custom deployer)
        console.log("\nAttempting to compute standard pool address...");
        const standardPoolAddress = await poolAddressTest.computeStandardPoolAddress(
            poolDeployer,
            tokenA,
            tokenB
        );
        console.log("Success! Standard pool address:", standardPoolAddress);

    } catch (error) {
        console.error("\nError occurred:");
        console.error(error.message);
        
        // If tokens are in wrong order, try swapping them
        if (error.message.includes("Invalid order")) {
            console.log("\nRetrying with swapped token order...");
            try {
                const poolAddress = await poolAddressTest.computePoolAddress(
                    poolDeployer,
                    customDeployer,
                    tokenB,  // Swapped order
                    tokenA   // Swapped order
                );
                console.log("Success with swapped tokens! Pool address:", poolAddress);
            } catch (swapError) {
                console.error("Error even with swapped tokens:", swapError.message);
            }
        }
    }

    // Additional validation
    console.log("\nValidation Information:");
    console.log("All addresses are valid:", [poolDeployer, customDeployer, tokenA, tokenB].every(addr => ethers.utils.isAddress(addr)));
    console.log("All addresses are non-zero:", [poolDeployer, customDeployer, tokenA, tokenB].every(addr => addr !== ethers.constants.AddressZero));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\nScript failed:", error);
        process.exit(1);
    }); 