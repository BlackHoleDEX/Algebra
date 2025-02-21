// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IVoterV3.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IMinter.sol";
import "./interfaces/IBribe.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
/// @title Automated Voting Manager
/// @notice Manages automated voting by delegating votes based on rewards per voting power
contract AutomatedVotingManager is Ownable, Initializable, ReentrancyGuard {
    
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

    int128 public minBalanceForAutovoting;
    uint256[] public tokenIds;

    mapping(uint256 => address) public originalOwner;
    mapping(uint256 => bool) public isAutoVotingEnabled;
    mapping(uint256 => bool) public hasVotedThisEpoch;

    event AutoVotingEnabled(uint256 lockId, address owner);
    event AutoVotingDisabled(uint256 lockId, address owner);
    event VotesExecuted(uint256 epoch, uint256 totalLocks);

    function initialize(
        address _voterV3,
        address _votingEscrow,
        address _chainlinkExecutor,
        address _minter
    ) public initializer {
        voterV3 = IVoterV3(_voterV3);
        votingEscrow = IVotingEscrow(_votingEscrow);
        chainlinkExecutor = _chainlinkExecutor;
        minter = _minter;
        minBalanceForAutovoting = 10;
    }

    /// @dev Restricts function to be callable only by Chainlink executor
    modifier onlyChainlink() {
        require(msg.sender == chainlinkExecutor, "Not authorized");
        _;
    }

    /// @notice Enables automated voting for a lock
    function enableAutoVoting(uint256 lockId) external nonReentrant {
        require(votingEscrow.isApprovedOrOwner(msg.sender, lockId), "Not owner nor approved");
        require(!isLastHour(), "Cannot enable in last hour before voting");
        require(votingEscrow.locked(lockId).amount > minBalanceForAutovoting, "Insufficient balance");

        votingEscrow.transferFrom(msg.sender, address(this), lockId);
        originalOwner[lockId] = msg.sender;
        isAutoVotingEnabled[lockId] = true;
        tokenIds.push(lockId);

        emit AutoVotingEnabled(lockId, msg.sender);
    }

    /// @notice Fetches gauges from VoterV3 for the given pools
    function getGaugesFromVoterV3(address[] memory pools) internal view returns (address[] memory) {
        address[] memory gauges = new address[](pools.length);
        for (uint256 i = 0; i < pools.length; i++) {
            gauges[i] = voterV3.gauges(pools[i]);
        }
        return gauges;
    }

    /// @notice Fetches rewards per voting power and returns the top N pools based on rewards
    function getRewardsPerVotingPower(uint256 topN) public view returns (PoolsAndRewards[] memory) {
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
            address[] memory rewardTokens = IBribe(bribeInternal).rewardTokens();

            for (uint256 j = 0; j < rewardTokens.length; j++) {
                address token = rewardTokens[j];
                uint256 internalBribes = IBribe(bribeInternal).tokenRewardsPerEpoch(token, epochStart);
                uint256 externalBribes = IBribe(bribeExternal).tokenRewardsPerEpoch(token, epochStart);
                totalRewardsPerVotingPower += (internalBribes + externalBribes);
            }

            uint256 totalVotes = voterV3.totalVotes(gauge);
            uint256 rewardsPerVotingPower = totalVotes > 0 ? (totalRewardsPerVotingPower * 1e18) / totalVotes : 0;

            poolRewards[i] = PoolsAndRewards({ 
                pool: pools[i], 
                gauge: gauge, 
                bribes: bribeInternal, 
                rewardsPerVotingPower: rewardsPerVotingPower 
            });
        }

        return _getTopNPools(poolRewards, topN);
    }

    /// @notice Selects the top N pools with the highest rewardsPerVotingPower
    function _getTopNPools(PoolsAndRewards[] memory pools, uint256 n) internal pure returns (PoolsAndRewards[] memory) {
        uint256 len = pools.length;
        if (n > len) {
            n = len; // Prevent overflow if `N` is greater than available pools
        }

        PoolsAndRewards[] memory topNPools = new PoolsAndRewards[](n);

        for (uint256 i = 0; i < n; i++) {
            uint256 maxIndex = i;
            for (uint256 j = i + 1; j < len; j++) {
                if (pools[j].rewardsPerVotingPower > pools[maxIndex].rewardsPerVotingPower) {
                    maxIndex = j;
                }
            }
            (pools[i], pools[maxIndex]) = (pools[maxIndex], pools[i]);
            topNPools[i] = pools[i];
        }

        return topNPools;
    }

    /// @notice Disables automated voting and transfers back the NFT to the original owner
    function disableAutoVoting(uint256 lockId) external nonReentrant {
        require(originalOwner[lockId] == msg.sender, "Not original owner");
        require(!isLastHour(), "Cannot disable in last hour before voting");

        votingEscrow.transferFrom(address(this), msg.sender, lockId);
        delete originalOwner[lockId];
        delete isAutoVotingEnabled[lockId];

        _removeTokenId(lockId);

        emit AutoVotingDisabled(lockId, msg.sender);
    }

    /// @dev Removes a lockId from the tokenIds array
    function _removeTokenId(uint256 lockId) internal {
        uint256 len = tokenIds.length;
        for (uint256 i = 0; i < len; i++) {
            if (tokenIds[i] == lockId) {
                tokenIds[i] = tokenIds[len - 1];
                tokenIds.pop();
                break;
            }
        }
    }

    /// @notice Returns equal weights for voting (Currently set to 1 for all pools)
    function getVoteWeightage(uint256 length) public pure returns (uint256[] memory weights) {
        weights = new uint256[](length); // ✅ Initialize array in memory
        for (uint256 i = 0; i < length; i++) {
            weights[i] = 1; // ✅ Assign values correctly
        }
        return weights;
    }


    /// @notice Executes automated voting at the end of each epoch
    function executeVotes(uint256 epoch) external onlyChainlink nonReentrant {
        require(isLastHour(), "Not in last hour of epoch");
        require(!hasVotedThisEpoch[epoch], "Already executed for this epoch");

        hasVotedThisEpoch[epoch] = true;
        PoolsAndRewards[] memory poolsAndRewards = getRewardsPerVotingPower(10);
        address[] memory poolAddresses = new address[](poolsAndRewards.length);

        for (uint256 i = 0; i < poolsAndRewards.length; i++) {
            poolAddresses[i] = poolsAndRewards[i].pool;
        }

        uint256[] memory weights = getVoteWeightage(poolAddresses.length); 

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 lockId = tokenIds[i];
            if (isAutoVotingEnabled[lockId]) {
                voterV3.vote(lockId, poolAddresses, weights);
            }
        }

        emit VotesExecuted(epoch, tokenIds.length);
    }

    function _calculateWeights(uint256[] memory baseWeights, uint256 votingPower) internal pure returns (uint256[] memory) {
        uint256[] memory adjustedWeights = new uint256[](baseWeights.length);
        for (uint256 i = 0; i < baseWeights.length; i++) {
            adjustedWeights[i] = baseWeights[i] * votingPower;
        }
        return adjustedWeights;
    }

    function isLastHour() public view returns (bool) {
        // return block.timestamp % 7 days >= 6 days + 23 hours;
        return block.timestamp % 30*60 >= 25*60;
    }

    function setChainlinkExecutor(address _executor) external onlyOwner {
        chainlinkExecutor = _executor;
    }
}
