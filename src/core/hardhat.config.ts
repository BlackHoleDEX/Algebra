import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-contract-sizer';
import 'hardhat-output-validator';
import 'solidity-docgen';
import { SolcUserConfig } from 'hardhat/types';
import baseConfig from '../../hardhat.base.config';

const HIGHEST_OPTIMIZER_COMPILER_SETTINGS: SolcUserConfig = {
  version: '0.8.20',
  settings: {
    evmVersion: 'paris',
    optimizer: {
      enabled: true,
      runs: 1_000_000,
    },
    metadata: {
      useLiteralContent: true, // use source code

      bytecodeHash: 'none',
    },
  },
};

const DEFAULT_COMPILER_SETTINGS: SolcUserConfig = {
  version: '0.8.20',
  settings: {
    evmVersion: 'paris',
    optimizer: {
      enabled: true,
      runs: 800,
    },
    metadata: {
      useLiteralContent: true, // use source code
      bytecodeHash: 'none',
    },
  },
};

const HIGH_COMPILER_SETTINGS: SolcUserConfig = {
  version: '0.8.20',
  settings: {
    evmVersion: 'paris',
    optimizer: {
      enabled: true,
      runs: 500,
    },
    metadata: {
      useLiteralContent: true, // use source code
      bytecodeHash: 'none',
    },
  },
};

if (process.env.RUN_COVERAGE == '1') {
  /**
   * Updates the default compiler settings when running coverage.
   *
   * See https://github.com/sc-forks/solidity-coverage/issues/417#issuecomment-730526466
   */
  console.info('Using coverage compiler settings');
  const details = {
    yul: true,
    yulDetails: {
      stackAllocation: true,
    },
  };

  HIGHEST_OPTIMIZER_COMPILER_SETTINGS.settings.details = details;
  DEFAULT_COMPILER_SETTINGS.settings.details = details;
}

export default {

  // networks: {
  //   monadTestnet: {
  //     url: "https://testnet-rpc.monad.xyz",
  //     chainId: 10143,
  //   },
  // },
  // sourcify: {
  //   enabled: true,
  //   apiUrl: "https://sourcify-api-monad.blockvision.org",
  //   browserUrl: "https://testnet.monadexplorer.com",
  // },
  // // To avoid errors from Etherscan
  // etherscan: {
  //   enabled: false,
  // },

  networks: {
    'monad': {
      url: 'https://testnet-rpc.monad.xyz',
      chainId: 10143
    },
  },
  sourcify: {
   enabled: true,
   apiUrl: "https://sourcify-api-monad.blockvision.org",
   browserUrl: "https://testnet.monadexplorer.com"
  },
  etherscan: {
    apiKey: {
      'monad': 'DUMMY_VALUE'
    },
    customChains: [
      {
        network: "monad",
        chainId: 10143,
        urls: {
          apiURL: "https://explorer.monad-testnet.category.xyz/api",
          browserURL: "https://explorer.monad-testnet.category.xyz"
        }
      }
    ]
  },

  
  // networks: baseConfig.networks,
  // etherscan: baseConfig.etherscan,
  typechain: {
    outDir: 'typechain',
  },
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS],
    overrides: {
      'contracts/AlgebraFactory.sol': HIGHEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/AlgebraPool.sol': HIGH_COMPILER_SETTINGS,
      'contracts/AlgebraPoolDeployer.sol': HIGH_COMPILER_SETTINGS,
    },
  },
  docgen: {
    outputDir: '../../docs/Contracts/Core',
    pages: (x: any, buildInfo: any) => {
      return `${buildInfo.relativePath}`.replace('.sol', '.md');
    },
    templates: '../../docs/doc_templates/public',
    collapseNewlines: true,
  },
  outputValidator: {
    runOnCompile: false,
    exclude: ['contracts/test'],
  },
};
