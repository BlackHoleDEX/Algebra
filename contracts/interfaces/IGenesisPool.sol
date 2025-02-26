// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IGenesisPoolBase.sol";

interface IGenesisPool {
    function getAllocationInfo() external view returns (IGenesisPoolBase.TokenAllocation memory);
    function getIncentivesInfo() external view returns (IGenesisPoolBase.TokenIncentiveInfo memory);
    function getGenesisInfo() external view returns (IGenesisPoolBase.GenesisInfo memory);
    function getProtocolInfo() external view returns (IGenesisPoolBase.ProtocolInfo memory);
    function getLiquidityPoolInfo() external view returns (IGenesisPoolBase.LiquidityPool memory);
    function poolStatus() external view returns (IGenesisPoolBase.PoolStatus);
    function userDeposits(address _user) external view returns (uint256);

    function setGenesisPoolInfo(IGenesisPoolBase.GenesisInfo calldata _genesisInfo, IGenesisPoolBase.ProtocolInfo calldata _protocolInfo, IGenesisPoolBase.TokenAllocation calldata _allocationInfo) external;
    function rejectPool() external;
    function approvePool(address _pairAddress) external;
    function depositToken(address spender, uint256 amount) external returns (bool);
    function transferIncentives(address gauge, address external_bribe, address internal_bribe) external;
    function eligbleForPreLaunchPool() external view returns (bool);
    function eligbleForCompleteLaunch() external view returns (bool);
    function eligbleForDisqualify() external view returns (bool);
    function getLaunchInfo() external view returns (IGenesisPoolBase.LaunchPoolInfo memory);
    function setPoolStatus(IGenesisPoolBase.PoolStatus status) external;
    function setLiquidity(uint256 liquidity) external;
    function approveTokens(address router) external;
    function balanceOf(address account) external view returns (uint256);
    function deductAmount(address account, uint256 amount) external;
    function deductAllAmount(address account) external;
    function setAuction(address _auction) external;
}