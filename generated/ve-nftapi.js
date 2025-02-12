const veNFTAPIAddress = "0xCdB651c1FC9FB05BaE940C5E7a2A8403b0bE07BC";

const veNFTAPIAbi = [
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
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "oldOwner",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "Owner",
    "type": "event"
  },
  {
    "inputs": [],
    "name": "MAX_PAIRS",
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
    "name": "MAX_RESULTS",
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
    "name": "WEEK",
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
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_amount",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "_offset",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "id",
        "type": "uint256"
      }
    ],
    "name": "allPairRewards",
    "outputs": [
      {
        "components": [
          {
            "components": [
              {
                "internalType": "uint256",
                "name": "id",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
              },
              {
                "internalType": "uint8",
                "name": "decimals",
                "type": "uint8"
              },
              {
                "internalType": "address",
                "name": "pair",
                "type": "address"
              },
              {
                "internalType": "address",
                "name": "token",
                "type": "address"
              },
              {
                "internalType": "address",
                "name": "bribe",
                "type": "address"
              },
              {
                "internalType": "string",
                "name": "symbol",
                "type": "string"
              }
            ],
            "internalType": "struct veNFTAPI.Reward[]",
            "name": "rewards",
            "type": "tuple[]"
          }
        ],
        "internalType": "struct veNFTAPI.AllPairRewards[]",
        "name": "rewards",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
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
    "name": "getAllNFT",
    "outputs": [
      {
        "components": [
          {
            "internalType": "uint8",
            "name": "decimals",
            "type": "uint8"
          },
          {
            "internalType": "bool",
            "name": "voted",
            "type": "bool"
          },
          {
            "internalType": "uint256",
            "name": "attachments",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "id",
            "type": "uint256"
          },
          {
            "internalType": "uint128",
            "name": "amount",
            "type": "uint128"
          },
          {
            "internalType": "uint256",
            "name": "voting_amount",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "rebase_amount",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "lockEnd",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "vote_ts",
            "type": "uint256"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "pair",
                "type": "address"
              },
              {
                "internalType": "uint256",
                "name": "weight",
                "type": "uint256"
              }
            ],
            "internalType": "struct veNFTAPI.pairVotes[]",
            "name": "votes",
            "type": "tuple[]"
          },
          {
            "internalType": "address",
            "name": "account",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "token",
            "type": "address"
          },
          {
            "internalType": "string",
            "name": "tokenSymbol",
            "type": "string"
          },
          {
            "internalType": "uint256",
            "name": "tokenDecimals",
            "type": "uint256"
          }
        ],
        "internalType": "struct veNFTAPI.veNFT[]",
        "name": "_veNFT",
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
    "name": "getAllPairRewards",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "totNFTs",
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
            "internalType": "uint256",
            "name": "id",
            "type": "uint256"
          },
          {
            "internalType": "uint128",
            "name": "lockedAmount",
            "type": "uint128"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "pair",
                "type": "address"
              },
              {
                "components": [
                  {
                    "internalType": "uint256",
                    "name": "id",
                    "type": "uint256"
                  },
                  {
                    "internalType": "uint256",
                    "name": "amount",
                    "type": "uint256"
                  },
                  {
                    "internalType": "uint8",
                    "name": "decimals",
                    "type": "uint8"
                  },
                  {
                    "internalType": "address",
                    "name": "pair",
                    "type": "address"
                  },
                  {
                    "internalType": "address",
                    "name": "token",
                    "type": "address"
                  },
                  {
                    "internalType": "address",
                    "name": "bribe",
                    "type": "address"
                  },
                  {
                    "internalType": "string",
                    "name": "symbol",
                    "type": "string"
                  }
                ],
                "internalType": "struct veNFTAPI.Reward[]",
                "name": "votingRewards",
                "type": "tuple[]"
              }
            ],
            "internalType": "struct veNFTAPI.PairReward[]",
            "name": "pairRewards",
            "type": "tuple[]"
          }
        ],
        "internalType": "struct veNFTAPI.LockReward[]",
        "name": "_lockReward",
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
        "name": "_user",
        "type": "address"
      }
    ],
    "name": "getNFTFromAddress",
    "outputs": [
      {
        "components": [
          {
            "internalType": "uint8",
            "name": "decimals",
            "type": "uint8"
          },
          {
            "internalType": "bool",
            "name": "voted",
            "type": "bool"
          },
          {
            "internalType": "uint256",
            "name": "attachments",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "id",
            "type": "uint256"
          },
          {
            "internalType": "uint128",
            "name": "amount",
            "type": "uint128"
          },
          {
            "internalType": "uint256",
            "name": "voting_amount",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "rebase_amount",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "lockEnd",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "vote_ts",
            "type": "uint256"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "pair",
                "type": "address"
              },
              {
                "internalType": "uint256",
                "name": "weight",
                "type": "uint256"
              }
            ],
            "internalType": "struct veNFTAPI.pairVotes[]",
            "name": "votes",
            "type": "tuple[]"
          },
          {
            "internalType": "address",
            "name": "account",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "token",
            "type": "address"
          },
          {
            "internalType": "string",
            "name": "tokenSymbol",
            "type": "string"
          },
          {
            "internalType": "uint256",
            "name": "tokenDecimals",
            "type": "uint256"
          }
        ],
        "internalType": "struct veNFTAPI.veNFT[]",
        "name": "venft",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "id",
        "type": "uint256"
      }
    ],
    "name": "getNFTFromId",
    "outputs": [
      {
        "components": [
          {
            "internalType": "uint8",
            "name": "decimals",
            "type": "uint8"
          },
          {
            "internalType": "bool",
            "name": "voted",
            "type": "bool"
          },
          {
            "internalType": "uint256",
            "name": "attachments",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "id",
            "type": "uint256"
          },
          {
            "internalType": "uint128",
            "name": "amount",
            "type": "uint128"
          },
          {
            "internalType": "uint256",
            "name": "voting_amount",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "rebase_amount",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "lockEnd",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "vote_ts",
            "type": "uint256"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "pair",
                "type": "address"
              },
              {
                "internalType": "uint256",
                "name": "weight",
                "type": "uint256"
              }
            ],
            "internalType": "struct veNFTAPI.pairVotes[]",
            "name": "votes",
            "type": "tuple[]"
          },
          {
            "internalType": "address",
            "name": "account",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "token",
            "type": "address"
          },
          {
            "internalType": "string",
            "name": "tokenSymbol",
            "type": "string"
          },
          {
            "internalType": "uint256",
            "name": "tokenDecimals",
            "type": "uint256"
          }
        ],
        "internalType": "struct veNFTAPI.veNFT",
        "name": "",
        "type": "tuple"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_voter",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_rewarddistro",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_pairApi",
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
  },
  {
    "inputs": [],
    "name": "pairAPI",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pairFactory",
    "outputs": [
      {
        "internalType": "contract IPairFactory",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "rewardDisitributor",
    "outputs": [
      {
        "internalType": "contract IRewardsDistributor",
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
        "name": "_owner",
        "type": "address"
      }
    ],
    "name": "setOwner",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_pairApi",
        "type": "address"
      }
    ],
    "name": "setPairAPI",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_pairFactory",
        "type": "address"
      }
    ],
    "name": "setPairFactory",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_rewarddistro",
        "type": "address"
      }
    ],
    "name": "setRewardDistro",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_voter",
        "type": "address"
      }
    ],
    "name": "setVoter",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "id",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "_pair",
        "type": "address"
      }
    ],
    "name": "singlePairReward",
    "outputs": [
      {
        "components": [
          {
            "internalType": "uint256",
            "name": "id",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "amount",
            "type": "uint256"
          },
          {
            "internalType": "uint8",
            "name": "decimals",
            "type": "uint8"
          },
          {
            "internalType": "address",
            "name": "pair",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "token",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "bribe",
            "type": "address"
          },
          {
            "internalType": "string",
            "name": "symbol",
            "type": "string"
          }
        ],
        "internalType": "struct veNFTAPI.Reward[]",
        "name": "_reward",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "underlyingToken",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "ve",
    "outputs": [
      {
        "internalType": "contract IVotingEscrow",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "voter",
    "outputs": [
      {
        "internalType": "contract IVoter",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "voterV3",
    "outputs": [
      {
        "internalType": "contract IVoterV3",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
];

module.exports = {veNFTAPIAddress, veNFTAPIAbi};