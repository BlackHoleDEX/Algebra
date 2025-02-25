// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IGanesisPoolBase.sol";

interface IGenesisPool {
    function setGenesisPoolInfo(IGanesisPoolBase.GenesisInfo calldata _genesisInfo, IGanesisPoolBase.ProtocolInfo calldata _protocolInfo, uint256 _proposedNativeAmount, uint _proposedFundingAmount) external;
}