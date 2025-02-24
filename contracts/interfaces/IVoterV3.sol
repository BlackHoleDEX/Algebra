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
    function createGauge(address _pool, uint256 _gaugeType) external returns (address _gauge, address _internal_bribe, address _external_bribe);
    function whitelist(address _token) external;
    function blacklist(address _token) external;
}