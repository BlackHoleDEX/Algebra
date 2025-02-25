// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IGanesisPoolBase.sol";

interface IGenesisPoolManager {
    function proposedTokens() external view returns(address[] memory tokens);
    function allocationsInfo(address token) external view returns(IGanesisPoolBase.TokenAllocation memory tokenAllocation);
    function incentivesInfo(address token) external view returns(IGanesisPoolBase.TokenIncentiveInfo memory tokenIncentives);
    function genesisPoolsInfo(address token) external view returns(IGanesisPoolBase.GenesisInfo memory genesisPoolInfo);
    function protocolsInfo(address token) external view returns(IGanesisPoolBase.ProtocolInfo memory protocolInfo);
    function poolsStatus(address token) external view returns(IGanesisPoolBase.PoolStatus poolStatus);
    function liquidityPoolsInfo(address token) external view returns(IGanesisPoolBase.LiquidityPool memory liquidityPool);
    function userDeposits(address token, address user) external view returns(uint256 amount);
    function getIncentiveTokens() external view returns(address[] memory tokens);
}
