// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IGanesisPoolBase {
    struct TokenAllocation {
        address tokenOwner;
        uint256 proposedNativeAmount;
        uint256 proposedFundingAmount;
        uint256 allocatedNativeAmount;
        uint256 allocatedFundingAmount;

        uint256 refundableNativeAmount;
    }

    struct TokenIncentiveInfo{
        address tokenOwner;
        address[] incentivesToken;
        uint256[] incentivesAmount;
    }

    struct GenesisInfo{
        address fundingToken;
        uint256 duration;
        uint8 threshold; // multiplied by 100 to support 2 decimals
        uint256 supplyPercent; 
        uint256 startPrice;
        uint256 startTime;
    }

    struct ProtocolInfo {
        address tokenAddress;
        string tokenName;
        string tokenTicker;
        string tokenIcon;
        bool stable;
        string protocolDesc;
        string protocolBanner;
    }

    struct LiquidityPool {
        address pairAddress;
        address gaugeAddress;
        address internal_bribe;
        address external_bribe;
    }

    struct GuageInfo {
        address gaugeAddress;
        address internal_bribe;
        address external_bribe;
    }

    enum PoolStatus{
        DEFAULT,
        NATIVE_TOKEN_DEPOSITED,
        APPLIED,
        PRE_LISTING,
        PRE_LAUNCH,
        PRE_LAUNCH_DEPOSIT_DISABLED,
        LAUNCH,
        PARTIALLY_LAUNCHED,
        NOT_QUALIFIED
    }
}