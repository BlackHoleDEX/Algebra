// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IGanesisPoolBase.sol";

interface IGenesisPool {
    function allocation() external view returns (IGanesisPoolBase.TokenAllocation memory);
    function incentives() external view returns (IGanesisPoolBase.TokenIncentiveInfo memory);
    function genesis() external view returns (IGanesisPoolBase.GenesisInfo memory);
    function protocol() external view returns (IGanesisPoolBase.ProtocolInfo memory);
    function liquidityPool() external view returns (IGanesisPoolBase.LiquidityPool memory);
    function poolStatus() external view returns (IGanesisPoolBase.PoolStatus);

    function setGenesisPoolInfo(IGanesisPoolBase.GenesisInfo calldata _genesisInfo, IGanesisPoolBase.ProtocolInfo calldata _protocolInfo, uint256 _proposedNativeAmount, uint _proposedFundingAmount) external;
    function addIncentives(address _sender, address _nativeToken, address[] calldata _incentivesToken, uint256[] calldata _incentivesAmount) external;
}