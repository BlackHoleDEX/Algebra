import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-contract-sizer';
import { SolcUserConfig } from 'hardhat/types';

const HIGHEST_OPTIMIZER_COMPILER_SETTINGS: SolcUserConfig = {
    version: '0.8.20',
    settings: {
        evmVersion: 'paris',
        optimizer: {
            enabled: true,
            runs: 1_000_000,
        },
        metadata: {
            bytecodeHash: 'none',
        },
    },
};

export default {
    solidity: {
        compilers: [HIGHEST_OPTIMIZER_COMPILER_SETTINGS],
    },
    contractSizer: {
        runOnCompile: true,
        strict: true,
    },
};
