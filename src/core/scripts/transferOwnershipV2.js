const hre = require('hardhat');
const fs = require('fs');
const path = require('path');

async function main() {
  const multisigAddress = process.env.MULTI_SIG_WALLET;
  const opsMultisigAddress = process.env.OPS_MULTI_SIG_WALLET;

  if (!multisigAddress || !opsMultisigAddress) {
    console.error('Please set MULTI_SIG_WALLET and OPS_MULTI_SIG_WALLET environment variables');
    process.exit(1);
  }

  if (!hre.ethers.isAddress(multisigAddress) || !hre.ethers.isAddress(opsMultisigAddress)) {
    console.error('Invalid multisig address provided');
    process.exit(1);
  }

  console.log(`Starting V2 ownership transfer to multisig: ${multisigAddress}`);
  console.log(`OPS multisig: ${opsMultisigAddress}`);

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

  console.log('\n=== STARTING V2 OWNERSHIP TRANSFER ===');

  // 1. TransparentUpgradeableProxy (NonfungibleTokenPositionDescriptor proxy) — transfer admin
  if (deploysData.proxy) {
    console.log('\n1. Managing TransparentUpgradeableProxy admin...');
    try {
      // Read the actual current admin from the EIP-1967 admin storage slot
      // instead of relying on deploysData.admin which may be stale
      const EIP1967_ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
      const rawAdmin = await hre.ethers.provider.getStorage(deploysData.proxy, EIP1967_ADMIN_SLOT);
      const currentProxyAdmin = hre.ethers.getAddress('0x' + rawAdmin.slice(26));
      console.log(`   Current proxy admin (EIP-1967): ${currentProxyAdmin}`);

      if (currentProxyAdmin.toLowerCase() === multisigAddress.toLowerCase()) {
        console.log(`   ⚠️  Proxy admin is already the multisig — skipping`);
        return;
      }

      const adminCode = await hre.ethers.provider.getCode(currentProxyAdmin);

      if (adminCode !== '0x') {
        // Admin is a ProxyAdmin contract
        const ProxyAdminABI = [
          'function owner() view returns (address)',
          'function transferOwnership(address newOwner) external',
        ];
        const proxyAdmin = new hre.ethers.Contract(currentProxyAdmin, ProxyAdminABI, deployer);
        const proxyAdminOwner = await proxyAdmin.owner();
        console.log(`   ProxyAdmin contract owner: ${proxyAdminOwner}`);

        if (proxyAdminOwner.toLowerCase() === deployer.address.toLowerCase()) {
          const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
          const tx = await proxyAdmin.transferOwnership(multisigAddress, { maxFeePerGas, maxPriorityFeePerGas });
          await tx.wait();
          deploysData.admin = multisigAddress;
          fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8');
          console.log(`   ✅ ProxyAdmin ownership transferred. Transaction: ${tx.hash}`);
        } else {
          console.log(`   ⚠️  ProxyAdmin already owned by: ${proxyAdminOwner}`);
        }
      } else if (currentProxyAdmin.toLowerCase() === deployer.address.toLowerCase()) {
        // Admin is the deployer EOA — call changeAdmin() directly on the proxy
        const ProxyABI = ['function changeAdmin(address newAdmin) external'];
        const proxy = new hre.ethers.Contract(deploysData.proxy, ProxyABI, deployer);
        const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
        const tx = await proxy.changeAdmin(multisigAddress, { maxFeePerGas, maxPriorityFeePerGas });
        await tx.wait();
        deploysData.admin = multisigAddress;
        fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8');
        console.log(`   ✅ Proxy admin changed to multisig. Transaction: ${tx.hash}`);
      } else {
        console.log(`   ⚠️  Current proxy admin (${currentProxyAdmin}) is not the deployer — skipping`);
      }
    } catch (error) {
      console.error('   ❌ Error transferring proxy admin:', error.message);
    }
  } else {
    console.log('\n1. ⚠️  Proxy not found in deploys.json, skipping');
  }

  // Note: PluginV3Deployer and FarmingCenter have no admin — they are controlled entirely
  // by their immutable factory/eternalFarming references and require no ownership transfer.
  // SecurityRegistry access is governed by AlgebraFactory owner + GUARD role
  // (handled in transferOwnership.js).
}

main()
  .then(() => {
    console.log('\n🎉 V2 ownership transfer completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Fatal error during V2 ownership transfer:', error);
    process.exit(1);
  });