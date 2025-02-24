// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import {BlackTimeLibrary} from "./libraries/BlackTimeLibrary.sol";
import "./interfaces/IVoterV3.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IBribe.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title Automated Voting Manager
/// @notice Manages automated voting by delegating votes based on rewards per voting power
contract AutomatedVotingManager is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    /* ======= STRUCTS ======= */
    struct PoolsAndRewards {
        address pool;
        address gauge;
        address bribes;
        uint256 rewardsPerVotingPower;
    }

    /* ======= STATE VARIABLES ======= */
    IVoterV3 public voterV3;
    IVotingEscrow public votingEscrow;
    address public chainlinkExecutor;
    address public minter;

    int128 public minBalanceForAutovoting;
    uint256[] public tokenIds;

    uint256 public topN;

    mapping(uint256 => address) public originalOwner;
    mapping(uint256 => bool) public isAutoVotingEnabled;
    mapping(uint256 => bool) public hasVotedThisEpoch; // key is considered unix epoch value of dex epoch start

    /* ======= EVENTS ======= */
    event AutoVotingEnabled(uint256 lockId, address owner);
    event AutoVotingDisabled(uint256 lockId, address owner);
    event VotesExecuted(uint256 epoch, uint256 totalLocks);

    /* ======= MODIFIERS ======= */
    modifier onlyChainlink() {
        require(msg.sender == chainlinkExecutor, "Not authorized");
        _;
    }

    modifier onlyVotingEscrow() {
        require(msg.sender == address(votingEscrow), "Only VotingEscrow can call this");
        _;
    }

    /* ======= INITIALIZER ======= */
    function initialize(address _voterV3, address _votingEscrow, address _chainlinkExecutor, address _minter) public initializer {
        __Ownable_init(); // ✅ Initialize Ownable
        __ReentrancyGuard_init(); // ✅ Initialize ReentrancyGuard
        
        voterV3 = IVoterV3(_voterV3);
        votingEscrow = IVotingEscrow(_votingEscrow);
        chainlinkExecutor = _chainlinkExecutor;
        minter = _minter;
        minBalanceForAutovoting = 10*1e18; // decimals in black

        _transferOwnership(msg.sender); // ✅ Set contract owner correctly
    }

    /* ======= EXTERNAL FUNCTIONS ======= */
    /// @notice Enables automated voting for a lock
    function enableAutoVoting(uint256 lockId) external nonReentrant {
        require(votingEscrow.isApprovedOrOwner(msg.sender, lockId), "Not owner nor approved");
        require(!BlackTimeLibrary.isLastHour(block.timestamp), "Cannot enable in last hour before voting");
        require(votingEscrow.locked(lockId).amount > minBalanceForAutovoting, "Insufficient balance");

        votingEscrow.transferFrom(msg.sender, address(this), lockId);
        originalOwner[lockId] = msg.sender;
        isAutoVotingEnabled[lockId] = true;
        tokenIds.push(lockId);

        emit AutoVotingEnabled(lockId, msg.sender);
    }

    /// @notice Disables automated voting and transfers back the NFT to the original owner
    function disableAutoVoting(uint256 lockId) external nonReentrant {
        require(originalOwner[lockId] == msg.sender, "Not original owner");
        require(!BlackTimeLibrary.isLastHour(block.timestamp), "Cannot disable in last hour before voting");

        delete originalOwner[lockId];
        delete isAutoVotingEnabled[lockId];

        _removeTokenId(lockId);

        votingEscrow.transferFrom(address(this), msg.sender, lockId);

        emit AutoVotingDisabled(lockId, msg.sender);
    }

    /// @notice Executes automated voting at the end of each epoch
    function executeVotes(uint256 start, uint256 end) external onlyChainlink nonReentrant {
        require(start < end && end <= tokenIds.length, "Invalid range");
        require(BlackTimeLibrary.isLastHour(block.timestamp), "Not in last hour of epoch");
        require(!hasVotedThisEpoch[BlackTimeLibrary.epochStart(block.timestamp)], "Already executed for this epoch");
        require(tokenIds.length > 0, "No auto-voting locks available");
        hasVotedThisEpoch[BlackTimeLibrary.epochStart(block.timestamp)] = true;
        PoolsAndRewards[] memory poolsAndRewards = getRewardsPerVotingPower(topN);
        address[] memory poolAddresses = new address[](poolsAndRewards.length);
        for (uint256 i = 0; i < poolsAndRewards.length; i++) {
            poolAddresses[i] = poolsAndRewards[i].pool;
        }

        uint256[] memory weights = getVoteWeightage(poolsAndRewards);

        for (uint256 i = start; i < end; i++) {
            uint256 lockId = tokenIds[i];
            if (isAutoVotingEnabled[lockId]) {
                voterV3.vote(lockId, poolAddresses, weights);
            }
        }

        emit VotesExecuted(BlackTimeLibrary.epochStart(block.timestamp), end - start);
    }


    function setOriginalOwner(uint256 tokenId, address owner) external onlyVotingEscrow {
        require(owner != address(0), "Invalid owner address");
        require(tokenId != 0, "invalid token id");
        originalOwner[tokenId] = owner;
    }

    function setChainlinkExecutor(address _executor) external onlyOwner {
        require(_executor != address(0), "Invalid executor address");
        chainlinkExecutor = _executor;
    }

    function setTopN(uint256 _topN) external onlyOwner {
        require(_topN > 0, "top n is negative");
        topN = _topN
    }

    /* ======= PUBLIC VIEW FUNCTIONS ======= */
    /// @notice Fetches rewards per voting power and returns the top N pools based on rewards
    function getRewardsPerVotingPower(uint256 topN) public view returns (PoolsAndRewards[] memory) {
        // address[] memory pools = voterV3.pools(); // to use voterV3.length() and then iterate over it
        uint256 numPools = voterV3.length();
        PoolsAndRewards[] memory poolRewards = new PoolsAndRewards[](numPools);
        uint256 epochStart = BlackTimeLibrary.epochStart(block.timestamp);

        for (uint256 i = 0; i < numPools; i++) {
            address pool = voterV3.pools(i);
            address gauge = voterV3.gauges(pool);
            address bribeInternal = voterV3.internal_bribes(gauge);
            address bribeExternal = voterV3.external_bribes(gauge);
            uint256 totalRewardsPerVotingPower = 0;

            for (uint256 j = 0; j < IBribe(bribeInternal).rewardsListLength(); j++) {
                address token = IBribe(bribeInternal).rewardTokens(j);
                uint256 internalBribes = IBribe(bribeInternal).tokenRewardsPerEpoch(token, epochStart);
                totalRewardsPerVotingPower += (internalBribes);
            }

            for (uint256 j = 0; j < IBribe(bribeExternal).rewardsListLength(); j++) {
                address token = IBribe(bribeExternal).rewardTokens(j);
                uint256 externalBribes = IBribe(bribeExternal).tokenRewardsPerEpoch(token, epochStart);
                totalRewardsPerVotingPower += (externalBribes);
            }

            uint256 totalVotes = voterV3.weights(pool);
            uint256 rewardsPerVotingPower;
            // to account for pools that have no votes, so even the smallest amount of voting power voted on them can cause a huge apr
            if (totalVotes == 0 && totalRewardsPerVotingPower > 0) {
                rewardsPerVotingPower = type(uint256).max; // Assign max uint to signify infinite ratio
            } else {
                rewardsPerVotingPower = totalVotes > 0 ? (totalRewardsPerVotingPower * 1e18) / totalVotes : 0;
            }

            poolRewards[i] = PoolsAndRewards({ 
                pool: pool, 
                gauge: gauge, 
                bribes: bribeInternal, 
                rewardsPerVotingPower: rewardsPerVotingPower 
            });
        }

        return _getTopNPools(poolRewards, topN);
    }

    /* ======= PUBLIC PURE FUNCTIONS ======= */
    /// @notice Returns equal weights for voting (Currently set to 1 for all pools)
    function getVoteWeightage(PoolsAndRewards[] memory poolsAndRewards) public pure returns (uint256[] memory weights) {
        weights = new uint256[](poolsAndRewards.length); // ✅ Initialize array in memory
        for (uint256 i = 0; i < poolsAndRewards.length; i++) {
            weights[i] = 1;
        }
        return weights;
    }

    /* ======= INTERNAL FUNCTIONS ======= */
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

    /* ======= INTERNAL PURE FUNCTIONS ======= */
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

    function _calculateWeights(uint256[] memory baseWeights, uint256 votingPower) internal pure returns (uint256[] memory) {
        uint256[] memory adjustedWeights = new uint256[](baseWeights.length);
        for (uint256 i = 0; i < baseWeights.length; i++) {
            adjustedWeights[i] = baseWeights[i] * votingPower;
        }
        return adjustedWeights;
    }
}w
