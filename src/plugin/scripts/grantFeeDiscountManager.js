const hre = require('hardhat');
const fs = require('fs');
const path = require('path');

async function getFeeData() {
  const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
  return { maxFeePerGas, maxPriorityFeePerGas };
}

async function main() {
  const account = process.env.MANAGER_ADDRESS || process.env.ACCOUNT;
  if (!account) {
    console.error(
      'Set MANAGER_ADDRESS (or ACCOUNT) to the address that should get FEE_DISCOUNT_MANAGER on AlgebraFactory'
    );
    process.exit(1);
  }
  if (!hre.ethers.isAddress(account)) {
    console.error('MANAGER_ADDRESS is not a valid address');
    process.exit(1);
  }

  const deployDataPath = path.resolve(__dirname, '../../../' + (process.env.DEPLOY_ENV || '') + 'deploys.json');
  const deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));

  const factoryAddress = process.env.ALGEBRA_FACTORY || deploysData.factory;
  if (!factoryAddress) {
    console.error('No AlgebraFactory address: set ALGEBRA_FACTORY or ensure deploys.json has factory');
    process.exit(1);
  }

  const role = hre.ethers.id('FEE_DISCOUNT_MANAGER');

  const factoryAbi = [
    'function grantRole(bytes32 role, address account) external',
    'function hasRole(bytes32 role, address account) view returns (bool)',
  ];
  const [signer] = await hre.ethers.getSigners();
  const factory = new hre.ethers.Contract(factoryAddress, factoryAbi, signer);

  const already = await factory.hasRole(role, account);
  if (already) {
    console.log('Address already has FEE_DISCOUNT_MANAGER:', account);
    return;
  }

  console.log('Signer:', signer.address);
  console.log('AlgebraFactory:', factoryAddress);
  console.log('Grant FEE_DISCOUNT_MANAGER to:', account);
  console.log('Role bytes32:', role);

  const feeData = await getFeeData();
  const tx = await factory.grantRole(role, account, { ...feeData });
  console.log('grantRole tx:', tx.hash);
  await tx.wait();
  console.log('Done');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
