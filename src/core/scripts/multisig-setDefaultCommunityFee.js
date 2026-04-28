import Safe from '@safe-global/protocol-kit';
import { OperationType } from '@safe-global/types-kit';
import SafeApiKit from '@safe-global/api-kit';
import pkg from 'hardhat';
const { ethers } = pkg;
import fs from 'fs';

import { fileURLToPath } from 'url';
import path from 'path';
import { Interface } from 'ethers';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Define constants
const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.MNEMONIC;
const SAFE_ADDRESS = process.env.SAFE_ADDRESS;
const CHAIN_ID = BigInt(process.env.CHAIN_ID);
const TXN_SERVICE_URL = process.env.TXN_SERVICE_URL ?? '';

const NEW_COMMUNITY_FEE = 0;

const abi = ['function setDefaultCommunityFee(uint16 newDefaultCommunityFee) returns ()'];

async function main() {
  try {
    const communityFee = parseInt(NEW_COMMUNITY_FEE);
    if (isNaN(communityFee) || communityFee < 0 || communityFee > 65535) {
      console.error('❌ Error: NEW_COMMUNITY_FEE must be a valid uint16 (0-65535)');
      process.exit(1);
    }

    console.log(`📋 Setting default community fee to: ${communityFee}`);

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

    if (!deploysData.factory) {
      console.error('❌ Error: Factory address not found in deployment file');
      process.exit(1);
    }

    const accounts = await ethers.getSigners();
    const owner = accounts[0];
    const ownerAddress = owner.address;
    console.log('Owner address:', ownerAddress);
    console.log('Factory address:', deploysData.factory);

    // Initialize Safe SDK using the new unified interface
    const safe = await Safe.init({
      provider: RPC_URL,
      signer: PRIVATE_KEY,
      safeAddress: SAFE_ADDRESS,
    });

    console.log(`Initialized Safe SDK for: ${await safe.getAddress()}`);

    // Encode function call
    const abiInterface = new Interface(abi);
    const data = abiInterface.encodeFunctionData('setDefaultCommunityFee', [communityFee]);

    console.log(`📝 Encoded transaction data: ${data}`);

    const safeTransactionData = {
      to: deploysData.factory,
      value: '0',
      data,
      operation: OperationType.Call,
    };

    const safeTransaction = await safe.createTransaction({
      transactions: [safeTransactionData],
    });

    const safeTxHash = await safe.getTransactionHash(safeTransaction);
    console.log('Safe Tx Hash:', safeTxHash);

    // Sign the full transaction (not just the hash!)
    const signedSafeTx = await safe.signTransaction(safeTransaction);
    const senderSignature = signedSafeTx.signatures.get(ownerAddress.toLowerCase());

    if (!senderSignature) {
      console.log('Sender Error:', signedSafeTx);
      throw new Error('Signature not found for owner address');
    }

    // Propose transaction to the service
    const apiKit =
      TXN_SERVICE_URL && TXN_SERVICE_URL.length > 0
        ? new SafeApiKit({
            chainId: CHAIN_ID,
            txServiceUrl: TXN_SERVICE_URL,
          })
        : new SafeApiKit({
            chainId: CHAIN_ID,
          });

    const txResponse = await apiKit.proposeTransaction({
      safeAddress: SAFE_ADDRESS,
      safeTransactionData: safeTransaction.data,
      safeTxHash,
      senderAddress: ownerAddress,
      senderSignature: senderSignature.data,
    });

    console.log('✅ Transaction proposed successfully!');
    console.log('Transaction Service Response:', txResponse);
    console.log(`🔗 View: https://app.safe.global/transactions/tx?id=${safeTxHash}&safe=${SAFE_ADDRESS}`);
    console.log(`📊 Summary:`);
    console.log(`   - Function: setDefaultCommunityFee`);
    console.log(`   - New Community Fee: ${communityFee}`);
    console.log(`   - Target Contract: ${deploysData.factory}`);
  } catch (error) {
    console.log('Error in setDefaultCommunityFee proposal:', error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
