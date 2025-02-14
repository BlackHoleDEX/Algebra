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
    //function weightsAt(address _pool, uint _time) external view returns(uint);
    //function totalWeight() external view returns(uint);
    //function totalWeightAt(uint _time) external view returns(uint);
    function poke(uint256 _tokenId) external;
    function epochTimestamp() external view returns(uint);
    function lastVoted(uint tokenId) external view returns(uint);
}