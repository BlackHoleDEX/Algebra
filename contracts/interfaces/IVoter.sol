// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVoter {
    function _ve() external view returns (address);
    function gauges(address _pair) external view returns (address);
    function isGauge(address _gauge) external view returns (bool);
    function poolForGauge(address _gauge) external view returns (address);
    function factories() external view returns(address[] memory);
    function minter() external view returns(address);
    function notifyRewardAmount(uint amount) external;
    function distributeAll() external;
    function distributeFees() external;

    function internal_bribes(address _gauge) external view returns (address);
    function external_bribes(address _gauge) external view returns (address);

    function usedWeights(uint id) external view returns(uint);
    function lastVoted(uint id) external view returns(uint);
    function poolVote(uint id, uint _index) external view returns(address _pair);
    function votes(uint id, address _pool) external view returns(uint votes);
    function vote(uint256 _tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external;
    function poolVoteLength(uint tokenId) external view returns(uint);
    function lastVotedTimestamp(uint id) external view returns(uint);
    function length() external view returns (uint);
    function factoryLength() external view returns(uint);
    function gaugeFactories() external view returns(address[] memory);
    function gaugeFactoriesLength() external view returns(uint);
    function weights(address _pool) external view returns(uint);
    function poke(uint256 _tokenId) external;
    function epochTimestamp() external view returns(uint);
    function getBlackGovernor() external view returns (address);
    function setBlackGovernor(address _epochGovernor) external;
    function pools(uint256 i) external view returns(address);
    function createGauge(address _pool, uint256 _gaugeType) external returns (address _gauge, address _internal_bribe, address _external_bribe);
    function getEpochGovernor() external view returns (address);
    function setEpochGovernor(address _epochGovernor) external;
    function reset(uint256 _tokenId) external;
}
