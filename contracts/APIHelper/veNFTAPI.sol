
// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;


import '../libraries/Math.sol';
import '../interfaces/IBribeAPI.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IPair.sol';
import '../interfaces/IPairFactory.sol';
import '../interfaces/IVoter.sol';
import '../interfaces/IVotingEscrow.sol';
import '../interfaces/IRewardsDistributor.sol';
import '../interfaces/IVoterV3.sol';
import '../interfaces/IGaugeFactoryV2.sol';

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "hardhat/console.sol";

interface IPairAPI {
    struct Bribes {
        address bribeAddress;
        address[] tokens;
        string[] symbols;
        uint[] decimals;
        uint[] amounts;
    }

    struct Rewards {
        Bribes[] bribes;
    }

    function pair_factory() external view returns(address);
}

contract veNFTAPI is Initializable {

    struct pairVotes {
        address pair;
        uint256 weight;
    }

    struct InternalBribeInputs {
        uint id;
        address bribe_address;
        address t0;
        address t1;
        address pair;
    }

    struct ExternalBribeInputs {
        uint id;
        address bribe_address;
        uint tokens;
        address pair;
    }

    struct veNFT {
        uint8 decimals;
        
        bool voted;
        bool hasVotedForEpoch;
        uint256 attachments;

        uint256 id;
        uint128 amount;
        uint256 voting_amount;
        uint256 rebase_amount;
        uint256 lockEnd;
        uint256 vote_ts;
        pairVotes[] votes;        
        
        address account;
        
        bool isSMNFT;
        bool isPermanent;

        address token;
        string tokenSymbol;
        uint256 tokenDecimals;
    }

    struct Reward {
        
        uint256 id;
        uint256 amount;  
        uint8 decimals;
        
        address pair;
        address token;
        address bribe;

        string symbol;
    }

    struct PairReward {
        address pair;
        Reward[] votingRewards;
    }

    struct LockReward {
        uint256 id;
        uint128 lockedAmount;
        PairReward[] pairRewards;
    }
   
    uint256 constant public MAX_RESULTS = 1000;
    uint256 constant public MAX_PAIRS = 30;
    uint256 public constant WEEK = 1800; 

    IVoter public voter;
    IVoterV3 public voterV3;
    IGaugeFactory public gaugeFactoryV2;
    address public underlyingToken;
    

    IVotingEscrow public ve;
    IRewardsDistributor public rewardDisitributor;

    address public pairAPI;
    IPairFactory public pairFactory;
    

    address public owner;
    event Owner(address oldOwner, address newOwner);

    struct AllPairRewards {
        Reward[] rewards;
    }
    constructor() {}

    function initialize(address _voter, address _rewarddistro, address _pairApi, address _gaugeFactory) initializer public {

        owner = msg.sender;

        pairAPI = _pairApi;
        voter = IVoter(_voter);
        voterV3 = IVoterV3(_voter);
        rewardDisitributor = IRewardsDistributor(_rewarddistro);
        gaugeFactoryV2 = IGaugeFactory(_gaugeFactory);

        require(rewardDisitributor.voting_escrow() == voter._ve(), 've!=ve');
        
        ve = IVotingEscrow( rewardDisitributor.voting_escrow() );
        underlyingToken = IVotingEscrow(ve).token();

        pairFactory = IPairFactory(voter.factories()[0]);
    }

    function getAllNFT(uint256 _amounts, uint256 _offset) external view returns(veNFT[] memory _veNFT){

        require(_amounts <= MAX_RESULTS, 'too many nfts');
        _veNFT = new veNFT[](_amounts);

        uint i = _offset;
        address _owner;

        for(i; i < _offset + _amounts; i++){
            _owner = ve.ownerOf(i);
            // if id_i has owner read data
            if(_owner != address(0)){
                _veNFT[i-_offset] = _getNFTFromId(i, _owner);
            }
        }
    }

    function getNFTFromId(uint256 id) external view returns(veNFT memory){
        return _getNFTFromId(id,ve.ownerOf(id));
    }

    function getNFTFromAddress(address _user) external view returns(veNFT[] memory venft){

        uint256 totNFTs = (_user != address(0)) ? ve.balanceOf(_user) : 0;

        venft = new veNFT[](totNFTs);
        uint256 i=0;
        uint256 _id;

        for(i; i < totNFTs; i++){
            _id = ve.tokenOfOwnerByIndex(_user, i);
            if(_id != 0){
                venft[i] = _getNFTFromId(_id, _user);
            }
        }

        return venft;
    }

    function _getNFTFromId(uint256 id, address _owner) internal view returns(veNFT memory venft){

        if(_owner == address(0)){
            return venft;
        }

        uint _totalPoolVotes = voter.poolVoteLength(id);
        pairVotes[] memory votes = new pairVotes[](_totalPoolVotes);

        IVotingEscrow.LockedBalance memory _lockedBalance;
        _lockedBalance = ve.locked(id);

        uint k;
        uint256 _poolWeight;
        address _votedPair;

        for(k = 0; k < _totalPoolVotes; k++){

            _votedPair = voter.poolVote(id, k);
            if(_votedPair == address(0)){
                break;
            }
            _poolWeight = voter.votes(id, _votedPair);
            votes[k].pair = _votedPair;
            votes[k].weight = _poolWeight;
        }

        venft.id = id;
        venft.account = _owner;
        venft.decimals = ve.decimals();
        venft.amount = uint128(_lockedBalance.amount);
        venft.voting_amount = ve.balanceOfNFT(id);
        venft.rebase_amount = rewardDisitributor.claimable(id);
        venft.lockEnd = _lockedBalance.end;
        venft.vote_ts = voterV3.lastVotedTimestamp(id);
        venft.votes = votes;
        venft.token = ve.token();
        venft.tokenSymbol =  IERC20( ve.token() ).symbol();
        venft.tokenDecimals = IERC20( ve.token() ).decimals();
        venft.attachments = ve.attachments(id);
        venft.isSMNFT = _lockedBalance.isSMNFT;
        venft.isPermanent = _lockedBalance.isPermanent;
        
        venft.voted = ve.voted(id);
        venft.hasVotedForEpoch = (voterV3.epochTimestamp() < venft.vote_ts) && (venft.vote_ts < voterV3.epochTimestamp() + WEEK);
    }

    // used only for sAMM and vAMM    
    // function allPairRewards(uint256 _amount, uint256 _offset, uint256 id) external view returns(AllPairRewards[] memory rewards){
        
    //     rewards = new AllPairRewards[](MAX_PAIRS);

    //     uint256 totalPairs = pairFactory.allPairsLength();
        
    //     uint i = _offset;
    //     address _pair;
    //     address _gaugeAddress;
    //     for(i; i < _offset + _amount; i++){
    //         if(i >= totalPairs){
    //             break;
    //         }
    //         _pair = pairFactory.allPairs(i);
    //         _gaugeAddress = IVoter(voter).gauges(_pair);
    //         rewards[i].rewards = _pairReward(_pair, id, _gaugeAddress);
    //     }
    // }
    
    function _pairReward(address _pair, uint256 id,  address _gauge) internal view returns (Reward[] memory _reward, bool) {

        if (_gauge == address(0)) {
            return (_reward, false);
        }

        address external_bribe = voter.external_bribes(_gauge);
        address internal_bribe = voter.internal_bribes(_gauge);

        uint256 totBribeTokens = (external_bribe == address(0)) ? 0 : IBribeAPI(external_bribe).rewardsListLength();
        _reward = new Reward[](2 + totBribeTokens);

        // Fetch pair contract once
        IPair ipair = IPair(_pair);
        (address t0, address t1) = (ipair.token0(), ipair.token1());

        bool hasReward = false;

        InternalBribeInputs memory internal_bribes_input = InternalBribeInputs({
            id: id,
            t0: t0,
            t1: t1,
            bribe_address: internal_bribe,
            pair: _pair
        });

        ExternalBribeInputs memory external_bribes_input = ExternalBribeInputs({
            id: id,
            bribe_address: address(0),
            tokens: 0,
            pair: address(0)
        });

        // Fetch earned fees
        hasReward = _addInternalBribeRewards(_reward, internal_bribes_input);

        if (external_bribe != address(0)) {
            external_bribes_input.id = id;
            external_bribes_input.bribe_address = external_bribe;
            external_bribes_input.tokens = totBribeTokens;
            external_bribes_input.pair = _pair;
            hasReward = hasReward || _addExternalBribeRewards(_reward, external_bribes_input);
        }

        return (_reward, hasReward);
    }

    function getAllPairRewards(address _user, uint _amounts, uint _offset) external view returns(uint totNFTs, bool hasNext, LockReward[] memory _lockReward){
        
        if(_user == address(0)){

            return (totNFTs, hasNext, _lockReward);
        }

        totNFTs = ve.balanceOf(_user);

        uint length = _amounts < totNFTs ? _amounts : totNFTs;
        _lockReward = new LockReward[](length);

        uint i = _offset;
        uint256 nftId;
        hasNext = true;

        for(i; i < _offset + length; i++){
            if(i >= totNFTs) {
                hasNext = false;
                break;
            }
            
            nftId = ve.tokenOfOwnerByIndex(_user, i);

            _lockReward[i-_offset].id = nftId;
            _lockReward[i-_offset].lockedAmount = uint128(ve.locked(nftId).amount);
            _lockReward[i-_offset].pairRewards = _getRewardsForNft(nftId);
        }
    }

    function _getRewardsForNft(uint nftId) internal view returns (PairReward[] memory pairReward) {
        address[] memory allGauges = gaugeFactoryV2.gauges();
        uint gaugesLength = gaugeFactoryV2.length();
        uint maxPairRewardCount = 0;
        PairReward[] memory _pairRewards = new PairReward[](gaugesLength);

        for(uint i=0; i<gaugesLength; i++){
            address poolAddress = IVoter(voter).poolForGauge(allGauges[i]);
            (Reward[] memory _rewardData, bool hasReward) = _pairReward(poolAddress, nftId, allGauges[i]);
            if(hasReward)
            {
                _pairRewards[maxPairRewardCount].pair = poolAddress;
                _pairRewards[maxPairRewardCount].votingRewards = _rewardData;
                maxPairRewardCount++;
            }
        }

        pairReward = new PairReward[](maxPairRewardCount);

        for(uint i=0; i<maxPairRewardCount; i++){
            pairReward[i].pair = _pairRewards[i].pair;
            pairReward[i].votingRewards = _pairRewards[maxPairRewardCount].votingRewards;
        }
    }

    function _addInternalBribeRewards(Reward[] memory _reward, InternalBribeInputs memory internal_bribes_inputs) internal view returns (bool) {
        uint256 _feeToken0 = IBribeAPI(internal_bribes_inputs.bribe_address).earned(internal_bribes_inputs.id, internal_bribes_inputs.t0);
        uint256 _feeToken1 = IBribeAPI(internal_bribes_inputs.bribe_address).earned(internal_bribes_inputs.id, internal_bribes_inputs.t1);
        bool hasReward = false;
        if (_feeToken0 > 0) {
            _reward[0] = _createReward(internal_bribes_inputs.id, _feeToken0, internal_bribes_inputs.t0, internal_bribes_inputs.bribe_address, internal_bribes_inputs.pair);
            if(!hasReward) hasReward = true;
        }
        if (_feeToken1 > 0) {
            _reward[1] = _createReward(internal_bribes_inputs.id, _feeToken1, internal_bribes_inputs.t1, internal_bribes_inputs.bribe_address, internal_bribes_inputs.pair);
            if(!hasReward) hasReward = true;
        }

        return hasReward;
    }

    function _addExternalBribeRewards(Reward[] memory _reward, ExternalBribeInputs memory external_bribes_input) internal view returns (bool) {
        bool hasReward = false;
        for (uint256 k = 0; k < external_bribes_input.tokens; k++) {
            address _token = IBribeAPI(external_bribes_input.bribe_address).rewardTokens(k);
            uint256 bribeAmount = IBribeAPI(external_bribes_input.bribe_address).earned(external_bribes_input.id, _token);
            hasReward = bribeAmount > 0;
            _reward[2 + k] = _createReward(external_bribes_input.id, bribeAmount, _token, external_bribes_input.bribe_address, external_bribes_input.pair);
        }

        return hasReward;
    }

    function _createReward(uint256 id, uint256 amount, address token, address bribe, address _pair) internal view returns (Reward memory) {
        return Reward({
            id: id,
            pair: _pair,
            amount: amount,
            token: token,
            symbol: IERC20(token).symbol(),
            decimals: IERC20(token).decimals(),
            bribe: bribe
        });
    }
    

    function setOwner(address _owner) external {
        require(msg.sender == owner, 'not owner');
        require(_owner != address(0), 'zeroAddr');
        owner = _owner;
        emit Owner(msg.sender, _owner);
    }

    
    function setVoter(address _voter) external  {
        require(msg.sender == owner);

        voter = IVoter(_voter);
    }


    function setRewardDistro(address _rewarddistro) external {
        require(msg.sender == owner);
        
        rewardDisitributor = IRewardsDistributor(_rewarddistro);
        require(rewardDisitributor.voting_escrow() == voter._ve(), 've!=ve');

        ve = IVotingEscrow( rewardDisitributor.voting_escrow() );
        underlyingToken = IVotingEscrow(ve).token();
    }
    
    function setPairAPI(address _pairApi) external {
        require(msg.sender == owner);
        
        pairAPI = _pairApi;
    }


    function setPairFactory(address _pairFactory) external {
        require(msg.sender == owner);  
        pairFactory = IPairFactory(_pairFactory);
    }

}
