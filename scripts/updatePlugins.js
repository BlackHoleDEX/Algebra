#!/usr/bin/env node

require('dotenv/config');
const { ethers } = require('ethers');

// Minimal ABIs
const ALGEBRA_FACTORY_ABI = [
  // view helpers
  'function allPairsLength() external view returns (uint256)',
  'function allPairs(uint256) external view returns (address)',
  'function POOLS_ADMINISTRATOR_ROLE() external view returns (bytes32)',
  'function owner() external view returns (address)'
];

const POOL_IMMUTABLES_ABI = [
  'function token0() external view returns (address)',
  'function token1() external view returns (address)',
  'function plugin() external view returns (address)',
  'function tickSpacing() external view returns (int24)'
];

const BASE_PLUGIN_V1_FACTORY_ABI = [
  'function createPluginForExistingPool(address token0, address token1, address customPoolDeployer) external returns (address)',
  'function pluginByPool(address) external view returns (address)'
];

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

function getEnvAddress(...names) {
  for (const n of names) {
    const v = process.env[n];
    if (v && ethers.utils.isAddress(v)) return v;
    if (v && !ethers.utils.isAddress(v)) throw new Error(`Invalid address for env ${n}: ${v}`);
  }
  return ethers.constants.AddressZero;
}

function buildTickSpacingDeployers() {
  const a1 = getEnvAddress('TICK_SPACING_1', 'tickSpacing_1');
  const a20 = getEnvAddress('TICK_SPACING_20', 'tickSpacing_20');
  const a100 = getEnvAddress('TICK_SPACING_100', 'tickSpacing_100');
  const a1000 = getEnvAddress('TICK_SPACING_1000', 'tickSpacing_1000');

  const map = { 1: a1, 20: a20, 100: a100, 1000: a1000 };

  console.log('Tick spacing deployers:', map);
  return map;
}

async function main() {
  // Env/config
  const RPC_URL = requireEnv('RPC_URL');
  const PRIVATE_KEY = requireEnv('PRIVATE_KEY');
  const ALGEBRA_FACTORY = requireEnv('ALGEBRA_FACTORY');
  const BASE_PLUGIN_V1_FACTORY = requireEnv('BASE_PLUGIN_V1_FACTORY');

  const START = Number(process.env.START || '0');
  const LIMIT = process.env.LIMIT ? Number(process.env.LIMIT) : undefined; // max items to process
  const DRY_RUN = (process.env.DRY_RUN || 'false').toLowerCase() === 'true';

  const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  const factory = new ethers.Contract(ALGEBRA_FACTORY, ALGEBRA_FACTORY_ABI, provider);
  const pluginFactory = new ethers.Contract(BASE_PLUGIN_V1_FACTORY, BASE_PLUGIN_V1_FACTORY_ABI, wallet);

  const spacingDeployers = buildTickSpacingDeployers();

  const signerAddr = await wallet.getAddress();
  const owner = await factory.owner();
  const role = await factory.POOLS_ADMINISTRATOR_ROLE();

  // Best-effort permission hint (cannot fully check off-chain role membership without AccessControl interface)
  console.log(`Signer: ${signerAddr}`);
  console.log(`Factory owner: ${owner}`);
  if (signerAddr.toLowerCase() !== owner.toLowerCase()) {
    console.log('Note: Signer is not the factory owner. Ensure it has POOLS_ADMINISTRATOR_ROLE.');
  }

  const total = await factory.allPairsLength();
  const totalNum = Number(total);
  const endExclusive = LIMIT ? Math.min(START + LIMIT, totalNum) : totalNum;

  console.log(`Pools total: ${totalNum}. Processing range [${START}, ${endExclusive}). Dry-run=${DRY_RUN}`);

  let processed = 0;
  let created = 0;
  let skipped = 0;
  let failed = 0;

  for (let i = START; i < endExclusive; i++) {
    try {
      const pool = await factory.allPairs(i);
      const poolC = new ethers.Contract(pool, POOL_IMMUTABLES_ABI, provider);
      const [token0, token1, currentPlugin, spacingRaw] = await Promise.all([
        poolC.token0(),
        poolC.token1(),
        poolC.plugin().catch(() => ethers.constants.AddressZero),
        poolC.tickSpacing().catch(() => 0)
      ]);

      const tickSpacing = Number(spacingRaw);
      const deployer = spacingDeployers[tickSpacing] || ethers.constants.AddressZero;

      // Optional pre-check via factory mapping if available
      let existingByFactory;
      try {
        existingByFactory = await pluginFactory.pluginByPool(pool);
      } catch {}

      console.log(
        `[${i}] pool=${pool} token0=${token0} token1=${token1} tickSpacing=${tickSpacing} deployer=${deployer} plugin(pool)=${currentPlugin} pluginByPool=${existingByFactory}`
      );

      if (existingByFactory && existingByFactory !== ethers.constants.AddressZero) {
        skipped++;
        continue;
      }

      if (DRY_RUN) {
        console.log(
          `  DRY-RUN: would call createPluginForExistingPool(${token0}, ${token1}, ${deployer})`
        );
        created++;
        continue;
      }

      const tx = await pluginFactory.createPluginForExistingPool(token0, token1, deployer);
      console.log(`  tx sent: ${tx.hash}`);
      const receipt = await tx.wait();
      console.log(`  tx mined in block ${receipt.blockNumber}`);
      created++;
    } catch (err) {
      const msg = (err && err.error && err.error.message) || (err && err.message) || String(err);
      if (/Already created/i.test(msg)) {
        console.log('  already created -> skip');
        skipped++;
        continue;
      }
      console.warn(`  failed: ${msg}`);
      failed++;
    } finally {
      processed++;
    }
  }

  console.log(`Done. processed=${processed} created=${created} skipped=${skipped} failed=${failed}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
}); 