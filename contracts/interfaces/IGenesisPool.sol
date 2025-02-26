// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IGanesisPoolBase.sol";

interface IGenesisPool {
    function getAllocationInfo() external view returns (IGanesisPoolBase.TokenAllocation memory);
    function getIncentivesInfo() external view returns (IGanesisPoolBase.TokenIncentiveInfo memory);
    function getGenesisInfo() external view returns (IGanesisPoolBase.GenesisInfo memory);
    function getProtocolInfo() external view returns (IGanesisPoolBase.ProtocolInfo memory);
    function getLiquidityPoolInfo() external view returns (IGanesisPoolBase.LiquidityPool memory);
    function poolStatus() external view returns (IGanesisPoolBase.PoolStatus);
    function userDeposits(address _user) external view returns (uint256);

    function setGenesisPoolInfo(IGanesisPoolBase.GenesisInfo calldata _genesisInfo, IGanesisPoolBase.ProtocolInfo calldata _protocolInfo, IGanesisPoolBase.TokenAllocation calldata _allocationInfo) external;
    function rejectPool() external;
    function approvePool(address _pairAddress) external;
    function depositToken(address spender, uint256 amount) external returns (bool);
    function transferIncentives(address gauge, address external_bribe, address internal_bribe) external;
    function eligbleForPreLaunchPool() external view returns (bool);
    function eligbleForCompleteLaunch() external view returns (bool);
    function eligbleForDisqualify() external view returns (bool);
    function setLaunchStatus(IGanesisPoolBase.PoolStatus status) external returns (address, address, uint256, uint256, address, address, bool);
    function setPoolStatus(IGanesisPoolBase.PoolStatus status) external;
    function approveTokens(address router) external;
    function getLPTokensShares(uint256 liquidity) external returns (address[] memory, uint256[] memory, address);
    function setAuction(address _auction) external;
}