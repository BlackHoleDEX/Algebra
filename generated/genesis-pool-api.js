const genesisPoolAPIAddress = "0xE594d32695A627082d0f474360Cc60De86f550e1";

const genesisPoolAPIAbi = [
  {
    "inputs": [],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "uint8",
        "name": "version",
        "type": "uint8"
      }
    ],
    "name": "Initialized",
    "type": "event"
  },
  {
    "inputs": [],
    "name": "MAX_POOLS",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "genesisManager",
    "outputs": [
      {
        "internalType": "contract IGenesisPoolManager",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "genesisPoolFactory",
    "outputs": [
      {
        "internalType": "contract IGenesisPoolFactory",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_user",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "_amounts",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "_offset",
        "type": "uint256"
      }
    ],
    "name": "getAllGenesisPools",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "totPairs",
        "type": "uint256"
      },
      {
        "internalType": "bool",
        "name": "hasNext",
        "type": "bool"
      },
      {
        "components": [
          {
            "internalType": "address",
            "name": "protocolToken",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "userDeposit",
            "type": "uint256"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "tokenOwner",
                "type": "address"
              },
              {
                "internalType": "uint256",
                "name": "proposedNativeAmount",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "proposedFundingAmount",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "allocatedNativeAmount",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "allocatedFundingAmount",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "refundableNativeAmount",
                "type": "uint256"
              }
            ],
            "internalType": "struct IGenesisPoolBase.TokenAllocation",
            "name": "tokenAllocation",
            "type": "tuple"
          },
          {
            "components": [
              {
                "internalType": "address[]",
                "name": "incentivesToken",
                "type": "address[]"
              },
              {
                "internalType": "uint256[]",
                "name": "incentivesAmount",
                "type": "uint256[]"
              }
            ],
            "internalType": "struct IGenesisPoolBase.TokenIncentiveInfo",
            "name": "incentiveInfo",
            "type": "tuple"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "fundingToken",
                "type": "address"
              },
              {
                "internalType": "uint256",
                "name": "duration",
                "type": "uint256"
              },
              {
                "internalType": "uint8",
                "name": "threshold",
                "type": "uint8"
              },
              {
                "internalType": "uint256",
                "name": "supplyPercent",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "startPrice",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "startTime",
                "type": "uint256"
              }
            ],
            "internalType": "struct IGenesisPoolBase.GenesisInfo",
            "name": "genesisInfo",
            "type": "tuple"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "tokenAddress",
                "type": "address"
              },
              {
                "internalType": "string",
                "name": "tokenName",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "tokenTicker",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "tokenIcon",
                "type": "string"
              },
              {
                "internalType": "bool",
                "name": "stable",
                "type": "bool"
              },
              {
                "internalType": "string",
                "name": "protocolDesc",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "protocolBanner",
                "type": "string"
              }
            ],
            "internalType": "struct IGenesisPoolBase.ProtocolInfo",
            "name": "protocolInfo",
            "type": "tuple"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "pairAddress",
                "type": "address"
              },
              {
                "internalType": "address",
                "name": "gaugeAddress",
                "type": "address"
              },
              {
                "internalType": "address",
                "name": "internal_bribe",
                "type": "address"
              },
              {
                "internalType": "address",
                "name": "external_bribe",
                "type": "address"
              }
            ],
            "internalType": "struct IGenesisPoolBase.LiquidityPool",
            "name": "liquidityPool",
            "type": "tuple"
          },
          {
            "internalType": "enum IGenesisPoolBase.PoolStatus",
            "name": "poolStatus",
            "type": "uint8"
          }
        ],
        "internalType": "struct GenesisPoolAPI.GenesisData[]",
        "name": "genesisPools",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_genesisManager",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_genesisPoolFactory",
        "type": "address"
      }
    ],
    "name": "initialize",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
];

module.exports = {genesisPoolAPIAddress, genesisPoolAPIAbi};