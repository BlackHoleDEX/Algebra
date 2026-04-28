import Safe from '@safe-global/protocol-kit';
import { OperationType } from '@safe-global/types-kit';
import SafeApiKit from '@safe-global/api-kit';
import pkg from 'hardhat';
const { ethers } = pkg;
import fs from 'fs';

import { fileURLToPath } from 'url';
import path from 'path';
import { Interface } from 'ethers'

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);


// Define constants
const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.MNEMONIC;
const SAFE_ADDRESS = process.env.SAFE_ADDRESS;
const CHAIN_ID = BigInt(process.env.CHAIN_ID);
const TXN_SERVICE_URL = process.env.TXN_SERVICE_URL?? '';


const abi = [
  'function acceptOwnership() returns ()',
];


async function main () {
  try{

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


    const accounts = await ethers.getSigners();
    const owner = accounts[0];
    const ownerAddress = owner.address;
    console.log("ownerAddress : ", ownerAddress)

    // Initialize Safe SDK using the new unified interface
    const safe = await Safe.init({
      provider: RPC_URL,
      signer: PRIVATE_KEY,
      safeAddress: SAFE_ADDRESS,
    });

    console.log(`Initialized Safe SDK for: ${await safe.getAddress()}`);


    const abiPath = path.join(__dirname, '../artifacts/contracts/AlgebraVaultFactory.sol/AlgebraVaultFactory.json');
    const dataFile = fs.readFileSync(abiPath);
    const dataJson = JSON.parse(dataFile);
    console.log("JSON =================dataFile", dataJson, dataJson.abi, dataJson['abi']);
    const AlgebraVaultFactoryABI = JSON.stringify(dataJson.abi);

    const abiInterface = new Interface(abi);
    const data = abiInterface.encodeFunctionData('acceptOwnership', []);

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
    const apiKit = TXN_SERVICE_URL && TXN_SERVICE_URL.length > 0 ? new SafeApiKit({
        chainId: CHAIN_ID,
        txServiceUrl: TXN_SERVICE_URL,
      }) :
      new SafeApiKit({
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
  }
  catch(error){
    console.log("Error in aprrove token : ", error)
  }
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

