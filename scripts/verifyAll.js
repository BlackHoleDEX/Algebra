const execSync = require('child_process').execSync;

const network = process.argv[2];

const modules = ['core', 'plugin', 'periphery', 'farming'];

modules.forEach((module) => {
  console.log(`\n=== Verifying ${module} contracts ===`);
  try {
    execSync(`cd src/${module} && npx hardhat run --network ${network} scripts/verify.js`, { stdio: 'inherit' });
    console.log(`✅ ${module} verification completed successfully`);
  } catch (error) {
    console.log(`⚠️  ${module} verification completed with errors (but contracts may still be verified)`);
    console.log(`Error: ${error.message}`);
  }
});