// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVoterV3 {
    function lastVotedTimestamp(uint id) external view returns(uint);
    function length() external view returns (uint);
    function poolVoteLength(uint tokenId) external view returns(uint);
    function factories() external view returns(address[] memory);
    function factoryLength() external view returns(uint);
    function gaugeFactories() external view returns(address[] memory);
    function gaugeFactoriesLength() external view returns(uint);
    function weights(address _pool) external view returns(uint);
    function poke(uint256 _tokenId) external;
    function epochTimestamp() external view returns(uint);
    function lastVoted(uint tokenId) external view returns(uint);
    function gauges(address pool) external view returns(address);
    function pools(uint256 i) external view returns(address);
    function internal_bribes(address _gauge) external view returns(address);
    function external_bribes(address _gauge) external view returns(address);
    function vote(uint256 _tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external;
    function createGauge(address _pool, uint256 _gaugeType) external returns (address _gauge, address _internal_bribe, address _external_bribe);
    function getEpochGovernor() external view returns (address);
    function setEpochGovernor(address _epochGovernor) external;
}