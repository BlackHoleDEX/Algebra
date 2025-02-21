// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IVoterV3.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IMinter.sol";

interface IBribes {
    function getRewardsPerVotingPower(address rewardToken) external view returns (uint256);
}

contract AutomatedVotingManager is Ownable, ReentrancyGuard {

    struct PoolsAndRewards {
        address pool;
        address gauge;
        address bribes;
        uint256 rewardsPerVotingPower;
    }

    IVoterV3 public voterV3;
    IVotingEscrow public votingEscrow;
    address public chainlinkExecutor;
    address public minter;
    PoolsAndRewards[] public poolsAndRewards;

    mapping(uint256 => address) public originalOwner;
    mapping(uint256 => bool) public isAutoVotingEnabled;
    mapping(uint256 => bool) public hasVotedThisEpoch;

    event AutoVotingEnabled(uint256 lockId, address owner);
    event AutoVotingDisabled(uint256 lockId, address owner);
    event VotesExecuted(uint256 epoch, uint256 totalLocks);

    constructor(address _voterV3, address _votingEscrow, address _chainlinkExecutor, address _minter) {
        voterV3 = IVoterV3(_voterV3);
        votingEscrow = IVotingEscrow(_votingEscrow);
        chainlinkExecutor = _chainlinkExecutor;
        minter = _minter;
    }

    modifier onlyChainlink() {
        require(msg.sender == chainlinkExecutor, "Not authorized");
        _;
    }

    /// @notice Enables automated voting for a lock
    function enableAutoVoting(uint256 lockId) external nonReentrant {
        require(votingEscrow.isApprovedOrOwner(msg.sender, lockId), "Not owner nor approved");
        require(!isLastHour(), "Cannot enable in last hour before voting");
        require(votingEscrow.locked(lockId).amount > 10000, "Insufficient balance");

        // Transfer lock ownership to AVM
        votingEscrow.transferFrom(msg.sender, address(this), lockId);

        // Store the original owner
        originalOwner[lockId] = msg.sender;
        isAutoVotingEnabled[lockId] = true;

        emit AutoVotingEnabled(lockId, msg.sender);
    }

    function getGaugesFromVoterV3(address[] pools) internal view returns (address[] memory) {
        address[] memory gauges = new address[](pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            gauges[i] = voterV3.gauge(pools[i]); // Single SLOAD per iteration (2100 gas)
        }
        return gauges;
    }

    function getRewardsPerVotingPower() external view returns (PoolsAndRewards[] memory) {
    address[] memory pools = voterV3.pools();
    address[] memory gauges = getGaugesFromVoterV3(pools);
    
    uint256 numPools = pools.length;
    PoolsAndRewards[] memory poolRewards = new PoolsAndRewards[](numPools);

    uint256 epochStart = IMinter(minter).active_period();

    for (uint256 i = 0; i < numPools; i++) {
        address gauge = gauges[i];
        address bribeInternal = voterV3.internal_bribes(gauge);
        address bribeExternal = voterV3.external_bribes(gauge);

        uint256 totalRewardsPerVotingPower = 0;

        // Load reward tokens array once
        address[] memory rewardTokens = IBribes(bribeInternal).rewardTokens();

        // Iterate over rewardTokens and sum up rewards
        for (uint256 j = 0; j < rewardTokens.length; j++) {
            address token = rewardTokens[j];

            uint256 internalBribes = IBribes(bribeInternal).tokenRewardsPerEpoch(token, epochStart);
            uint256 externalBribes = IBribes(bribeExternal).tokenRewardsPerEpoch(token, epochStart);

            totalRewardsPerVotingPower += (internalBribes + externalBribes);
        }

        uint256 totalVotes = voterV3.totalVotes(gauge);
        uint256 rewardsPerVotingPower = totalVotes > 0 ? (totalRewardsPerVotingPower * 1e18) / totalVotes : 0;

        poolRewards[i] = PoolsAndRewards({
            pool: pools[i],
            gauge: gauge,
            bribes: bribeInternal, // Store only one bribe address (to save storage)
            rewardsPerVotingPower: rewardsPerVotingPower
        });
    }

    return _sortTopGauges(poolRewards);
}

    function _sortTopGauges(PoolsAndRewards[] _poolsAndRewards) internal view {
        return _poolsAndRewards;
    }


    function getTopPools() external view {

    }

    /// @notice Disables automated voting and returns lock to the original owner
    function disableAutoVoting(uint256 lockId) external nonReentrant {
        require(originalOwner[lockId] == msg.sender, "Not original owner");
        require(!isLastHour(), "Cannot disable in last hour before voting");

        // Transfer lock back to the original owner
        votingEscrow.transferFrom(address(this), msg.sender, lockId);

        // Clear stored data
        delete originalOwner[lockId];
        delete isAutoVotingEnabled[lockId];

        emit AutoVotingDisabled(lockId, msg.sender);
    }

    /// @notice Returns equal weights for voting (Currently set to 1 for all pools)
    function getVoteWeightage() public pure returns (uint256[] memory weights) {
        uint256;
        for (uint256 i = 0; i < 20; i++) {
            weights[i] = 1; // Default equal weighting
        }
        return weights;
    }

    /// @notice Chainlink executes votes at the end of each epoch
    function executeVotes(uint256 epoch) external onlyChainlink nonReentrant {
        require(isLastHour(), "Not in last hour of epoch");
        require(!hasVotedThisEpoch[epoch], "Already executed for this epoch");

        hasVotedThisEpoch[epoch] = true;

        uint256[] memory weights = getVoteWeightage();
        address[] memory pools = getTopPools(); // Fetch top pools from VoterV3

        uint256 totalLocks = votingEscrow.getActiveLocksCount();
        for (uint256 i = 0; i < totalLocks; i++) {
            uint256 lockId = votingEscrow.getLockByIndex(i);
            if (isAutoVotingEnabled[lockId]) {
                uint256 votingPower = votingEscrow.locked(lockId).amount;
                uint256[] memory weightPerLock = _calculateWeights(weights, votingPower);

                voterV3.vote(lockId, weightPerLock, pools);
            }
        }

        emit VotesExecuted(epoch, totalLocks);
    }

    /// @notice Calculates per-lock vote distribution
    function _calculateWeights(uint256[] memory baseWeights, uint256 votingPower) internal pure returns (uint256[] memory) {
        uint256[] memory adjustedWeights = new uint256[](baseWeights.length);
        for (uint256 i = 0; i < baseWeights.length; i++) {
            adjustedWeights[i] = baseWeights[i] * votingPower;
        }
        return adjustedWeights;
    }

    /// @notice Checks if it's the last hour before voting closes
    function isLastHour() public view returns (bool) {
        return block.timestamp % 7 days >= 6 days + 23 hours; // Adjust if voting cycle is different
    }

    /// @notice Allows owner to update Chainlink executor address
    function setChainlinkExecutor(address _executor) external onlyOwner {
        chainlinkExecutor = _executor;
    }
}
