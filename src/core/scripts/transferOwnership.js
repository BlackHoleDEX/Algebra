const hre = require('hardhat');
const fs = require('fs');
const path = require('path');

async function main() {
  const multisigAddress = process.env.MULTI_SIG_WALLET; //@Todo : replace this
  const opsMultisigAddress = process.env.OPS_MULTI_SIG_WALLET;

  if (!multisigAddress || !opsMultisigAddress) {
    console.error('Please provide multisig wallet address as second argument');
    process.exit(1);
  }

  if (!hre.ethers.isAddress(multisigAddress) || !hre.ethers.isAddress(opsMultisigAddress)) {
    console.error('Invalid multisig address provided');
    process.exit(1);
  }

  console.log(`Starting ownership transfer to multisig: ${multisigAddress}`);
  console.log(`Starting Guard transfer to ops multisig: ${opsMultisigAddress}`);

  // Read deployment addresses (environment-specific)
  const deployDataPath = path.resolve(__dirname, '../../../' + (process.env.DEPLOY_ENV || '') + 'deploys.json');
  let deploysData;
  try {
    deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));
    console.log(`Using deployment file: ${deployDataPath}`);
  } catch (error) {
    console.error(`Error reading deployment file ${deployDataPath}:`, error.message);
    process.exit(1);
  }

  const [deployer] = await hre.ethers.getSigners();
  console.log(`Current deployer address: ${deployer.address}`);

  // Contract interfaces
  const AlgebraFactoryABI = require('../artifacts/contracts/AlgebraFactory.sol/AlgebraFactory.json').abi;
  const AlgebraVaultFactoryABI = require('../artifacts/contracts/AlgebraVaultFactory.sol/AlgebraVaultFactory.json').abi;

  console.log('\n=== STARTING OWNERSHIP TRANSFER ===\n');

  // Grant GUARD role to OPS MultiSig
  if (deploysData.factory) {
    console.log('Granting GUARD role to OPS Multisig...');
    try {
      const factory = new hre.ethers.Contract(deploysData.factory, AlgebraFactoryABI, deployer);
      const tx = await factory.grantRole(keccak256('GUARD'), opsMultisigAddress);
      await tx.wait();
      console.log(`   ✅ GUARD role granted to OPS Multisig. Transaction: ${tx.hash}`);
    } catch (error) {
      console.error('   ❌ Error granting GUARD role:', error.message);
    }
  }

  // 1. Transfer AlgebraFactory ownership (uses Ownable2Step)
  if (deploysData.factory) {
    console.log('1. Transferring AlgebraFactory ownership...');
    try {
      const factory = new hre.ethers.Contract(deploysData.factory, AlgebraFactoryABI, deployer);

      // Check current owner
      const currentOwner = await factory.owner();
      console.log(`   Current owner: ${currentOwner}`);

      if (currentOwner.toLowerCase() === deployer.address.toLowerCase()) {
        console.log('   Initiating ownership transfer...');
        const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
        const tx = await factory.transferOwnership(multisigAddress, {
          maxFeePerGas,
          maxPriorityFeePerGas
        });
        await tx.wait();
        console.log(`   ✅ Transfer initiated. Transaction: ${tx.hash}`);
        console.log(`   ⚠️  IMPORTANT: Multisig must call acceptOwnership() to complete the transfer`);
      } else {
        console.log(`   ⚠️  Factory already owned by: ${currentOwner}`);
      }
    } catch (error) {
      console.error('   ❌ Error transferring factory ownership:', error.message);
    }
  }

  // 2. Transfer AlgebraVaultFactory ownership
  if (deploysData.vaultFactory) {
    console.log('\n2. Transferring AlgebraVaultFactory ownership...');
    try {
      const vaultFactory = new hre.ethers.Contract(deploysData.vaultFactory, AlgebraVaultFactoryABI, deployer);

      // Check current owner
      const currentOwner = await vaultFactory.owner();
      console.log(`   Current owner: ${currentOwner}`);

      if (currentOwner.toLowerCase() === deployer.address.toLowerCase()) {
        console.log('   Transferring ownership...');
        const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
        const tx = await vaultFactory.setOwner(multisigAddress, {
          maxFeePerGas,
          maxPriorityFeePerGas
        });
        await tx.wait();
        console.log(`   ✅ Ownership transferred. Transaction: ${tx.hash}`);
      } else {
        console.log(`   ⚠️  VaultFactory already owned by: ${currentOwner}`);
      }
    } catch (error) {
      console.error('   ❌ Error transferring vault factory ownership:', error.message);
    }
  }

  // 8. Transfer Proxy Admin (if exists)
  if (deploysData.proxy && deploysData.admin) {
    console.log('\n8. Managing Proxy Admin...');
    try {
      const ProxyAdminABI = ['function owner() view returns (address)', 'function transferOwnership(address newOwner) external'];

      // Check if admin is a contract (ProxyAdmin) or just an EOA
      const adminCode = await hre.ethers.provider.getCode(deploysData.admin);

      if (adminCode !== '0x') {
        // It's a ProxyAdmin contract
        const proxyAdmin = new hre.ethers.Contract(deploysData.admin, ProxyAdminABI, deployer);

        const currentAdmin = await proxyAdmin.owner();
        console.log(`   Current ProxyAdmin owner: ${currentAdmin}`);

        if (currentAdmin.toLowerCase() === deployer.address.toLowerCase()) {
          console.log('   Transferring ProxyAdmin ownership...');
          const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
          const tx = await proxyAdmin.transferOwnership(multisigAddress, {
            maxFeePerGas,
            maxPriorityFeePerGas
          });
          await tx.wait();
          console.log(`   ✅ ProxyAdmin ownership transferred. Transaction: ${tx.hash}`);
        } else {
          console.log(`   ⚠️  ProxyAdmin already owned by: ${currentAdmin}`);
        }
      } else {
        console.log(`   ⚠️  ProxyAdmin is EOA (${deploysData.admin}), manual transfer required`);
      }
    } catch (error) {
      console.error('   ❌ Error transferring proxy admin:', error.message);
    }
  }
}

// Error handling
main()
  .then(() => {
    console.log('\n🎉 Ownership transfer process completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Fatal error during ownership transfer:', error);
    process.exit(1);
  });
