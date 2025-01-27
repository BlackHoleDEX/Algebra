// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;


import '../libraries/Math.sol';
import '../interfaces/IBribeAPI.sol';
import '../interfaces/IGaugeAPI.sol';
import '../interfaces/IGaugeFactory.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IMinter.sol';
import '../interfaces/IPair.sol';
import '../interfaces/IPairInfo.sol';
import '../interfaces/IPairFactory.sol';
import '../interfaces/IVoter.sol';
import '../interfaces/IVotingEscrow.sol';
import '../../contracts/Pair.sol';
import './IVoterV3.sol';

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "hardhat/console.sol";

interface IHypervisor{
    function pool() external view returns(address);
    function getTotalAmounts() external view returns(uint tot0,uint tot1);
}

interface IAlgebraFactory{
    function poolByPair(address, address) external view returns(address);
}

contract BlackholePairAPIV2 is Initializable {

    struct pairInfo {
        // pair info
        address pair_address; 			// pair contract address
        string symbol; 				    // pair symbol
        string name;                    // pair name
        uint decimals; 			        // pair decimals
        bool stable; 				    // pair pool type (stable = false, means it's a variable type of pool)
        uint total_supply; 			    // pair tokens supply
    
        // token pair info
        address token0; 				// pair 1st token address
        string token0_symbol; 			// pair 1st token symbol
        uint token0_decimals; 		    // pair 1st token decimals
        uint reserve0; 			        // pair 1st token reserves (nr. of tokens in the contract)
        uint claimable0;                // claimable 1st token from fees (for unstaked positions)

        address token1; 				// pair 2nd token address
        string token1_symbol;           // pair 2nd token symbol
        uint token1_decimals;    		// pair 2nd token decimals
        uint reserve1; 			        // pair 2nd token reserves (nr. of tokens in the contract)
        uint claimable1; 			    // claimable 2nd token from fees (for unstaked positions)

        // pairs gauge
        address gauge; 				    // pair gauge address
        uint gauge_total_supply; 		// pair staked tokens (less/eq than/to pair total supply)
        uint emissions; 			    // pair emissions (per second)
        address emissions_token; 		// pair emissions token address
        uint emissions_token_decimals; 	// pair emissions token decimals

        // User deposit
        uint account_lp_balance; 		// account LP tokens balance
        uint account_token0_balance; 	// account 1st token balance
        uint account_token1_balance; 	// account 2nd token balance
        uint account_gauge_balance;     // account pair staked in gauge balance
        uint account_gauge_earned; 		// account earned emissions for this pair

        // votes
        uint votes;

        // fees
        address feeAddress; 
        uint token0_fees;      // token 0 fees accumulated till now
        uint token1_fees;      // token 1 fees accumulated till now

        // bribes
        Bribes internal_bribes;
        Bribes external_bribes;
    }

    struct tokenBribe {
        address token;
        uint8 decimals;
        uint256 amount;
        string symbol;
    }
    

    struct pairBribeEpoch {
        uint256 epochTimestamp;
        uint256 totalVotes;
        address pair;
        tokenBribe[] bribes;
    }

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

    uint256 public constant MAX_PAIRS = 1000;
    uint256 public constant MAX_EPOCHS = 200;
    uint256 public constant MAX_REWARDS = 16;
    uint256 public constant WEEK = 7 * 24 * 60 * 60;


    IPairFactory public pairFactory;
    IAlgebraFactory public algebraFactory;
    IVoter public voter;
    IVoterV3 public voterV3;

    address public underlyingToken;

    address public owner;


    event Owner(address oldOwner, address newOwner);
    event Voter(address oldVoter, address newVoter);
    event WBF(address oldWBF, address newWBF);

    constructor() {}

    function initialize(address _voter) initializer public {
  
        owner = msg.sender;

        voter = IVoter(_voter);
        voterV3 = IVoterV3(_voter);

        pairFactory = IPairFactory(voter.factories()[0]);
        underlyingToken = IVotingEscrow(voter._ve()).token();

        algebraFactory = IAlgebraFactory(address(0x306F06C147f064A010530292A1EB6737c3e378e4));
    }

    function getClaimable(address _account, address _pair) internal view returns(uint claimable0, uint claimable1){

        Pair pair = Pair(_pair);

        uint _supplied = pair.balanceOf(_account); // get LP balance of `_user`
        uint _claim0 = pair.claimable0(_account);
        uint _claim1 = pair.claimable1(_account);
        if (_supplied > 0) {
            uint _supplyIndex0 = pair.supplyIndex0(_account); // get last adjusted index0 for recipient
            uint _supplyIndex1 = pair.supplyIndex1(_account);
            uint _index0 = pair.index0(); // get global index0 for accumulated fees
            uint _index1 = pair.index1();
            uint _delta0 = _index0 - _supplyIndex0; // see if there is any difference that need to be accrued
            uint _delta1 = _index1 - _supplyIndex1;
            if (_delta0 > 0) {
                _claim0 += _supplied * _delta0 / 1e18; // add accrued difference for each supplied token
            }
            if (_delta1 > 0) {
                _claim1 += _supplied * _delta1 / 1e18;
            }
        } 

        return (_claim0, _claim1);
    }


    // valid only for sAMM and vAMM
    function getAllPair(address _user, uint _amounts, uint _offset) external view returns(uint totPairs, bool hasNext, pairInfo[] memory pairs){

        
        require(_amounts <= MAX_PAIRS, 'too many pair');

        pairs = new pairInfo[](_amounts);
        
        uint i = _offset;
        totPairs = pairFactory.allPairsLength();
        hasNext = true;
        address _pair;
        uint claim0;
        uint claim1;
        address feeAddress; 
        uint tokenCurrentFees0;     
        uint tokenCurrentFees1; 
        Bribes[] memory bribes;


        for(i; i < _offset + _amounts; i++){
            // if totalPairs is reached, break.
            if(i >= totPairs) {
                hasNext = false;
                break;
            }
            _pair = pairFactory.allPairs(i);
            pairs[i - _offset] = _pairAddressToInfo(_pair, _user);

            (claim0, claim1) = getClaimable(_user, _pair);
            pairs[i - _offset].claimable0 = claim0;
            pairs[i - _offset].claimable1 = claim1;

            (tokenCurrentFees0, tokenCurrentFees1, feeAddress) = getCurrentFees(_pair, pairs[i - _offset].token0, pairs[i - _offset].token1);
            pairs[i - _offset].feeAddress = feeAddress;
            pairs[i - _offset].token0_fees = tokenCurrentFees0;
            pairs[i - _offset].token1_fees = tokenCurrentFees1;  

            bribes = _getBribes(_pair);
            pairs[i - _offset].internal_bribes = bribes[0];
            pairs[i - _offset].external_bribes = bribes[1];  
        }


    }

    function getPair(address _pair, address _account) external view returns(pairInfo memory _pairInfo){
        pairInfo memory pairInformation =  _pairAddressToInfo(_pair, _account);
        uint claim0;
        uint claim1;
        address feeAddress; 
        uint tokenCurrentFees0;     
        uint tokenCurrentFees1; 

        (claim0, claim1) = getClaimable(_account, _pair);
        pairInformation.claimable0 = claim0;
        pairInformation.claimable1 = claim1;

        (tokenCurrentFees0, tokenCurrentFees1, feeAddress) = getCurrentFees(_pair, pairInformation.token0, pairInformation.token1);
        pairInformation.feeAddress = feeAddress;
        pairInformation.token0_fees = tokenCurrentFees0;
        pairInformation.token1_fees = tokenCurrentFees1;  

        Bribes[] memory bribes;
        bribes = _getBribes(_pair);
        pairInformation.internal_bribes = bribes[0];
        pairInformation.external_bribes = bribes[1];
        return pairInformation;
    }

    function _pairAddressToInfo(address _pair, address _account) internal view returns(pairInfo memory _pairInfo) {

        IPair ipair = IPair(_pair); 
        
        address token_0 = ipair.token0();
        address token_1 = ipair.token1();
        uint r0;
        uint r1;

        // checkout is v2 or v3? if v3 then load algebra pool 
        bool _type = IPairFactory(pairFactory).isPair(_pair);
        
        if(_type == false){
            // hypervisor totalAmounts = algebra.pool + gamma.unused
            // (r0,r1) = IHypervisor(_pair).getTotalAmounts();
        } else {
            (r0,r1,) = ipair.getReserves();
        }
    

        IGaugeAPI _gauge = IGaugeAPI(voter.gauges(_pair));
        uint accountGaugeLPAmount = 0;
        uint earned = 0;
        uint gaugeTotalSupply = 0;
        uint emissions = 0;
        
        {
            if(address(_gauge) != address(0)){
                if(_account != address(0)){
                    accountGaugeLPAmount = _gauge.balanceOf(_account);
                    earned = _gauge.earned(_account);
                } else {
                    accountGaugeLPAmount = 0;
                    earned = 0;
                }
                gaugeTotalSupply = _gauge.totalSupply();
                emissions = _gauge.rewardRate();
            }
        }
        

        // Pair General Info
        _pairInfo.pair_address = _pair;
        _pairInfo.symbol = ipair.symbol();
        _pairInfo.name = ipair.name();
        _pairInfo.decimals = ipair.decimals();
        _pairInfo.stable = _type == false ? false : ipair.isStable();
        _pairInfo.total_supply = ipair.totalSupply();        
        
        // Token0 Info
        _pairInfo.token0 = token_0;
        _pairInfo.token0_decimals = IERC20(token_0).decimals();
        _pairInfo.token0_symbol = IERC20(token_0).symbol();
        _pairInfo.reserve0 = r0;
        _pairInfo.claimable0 = _type == false ? 0 : ipair.claimable0(_account);

        // Token1 Info
        _pairInfo.token1 = token_1;
        _pairInfo.token1_decimals = IERC20(token_1).decimals();
        _pairInfo.token1_symbol = IERC20(token_1).symbol();
        _pairInfo.reserve1 = r1;
        _pairInfo.claimable1 = _type == false ? 0 : ipair.claimable1(_account);

        
        // Pair's gauge Info
        _pairInfo.gauge = address(_gauge);
        _pairInfo.gauge_total_supply = gaugeTotalSupply;
        _pairInfo.emissions = emissions;
        _pairInfo.emissions_token = underlyingToken;
        _pairInfo.emissions_token_decimals = IERC20(underlyingToken).decimals();			    

        // Account Info
        _pairInfo.account_lp_balance = IERC20(_pair).balanceOf(_account);
        _pairInfo.account_token0_balance = IERC20(token_0).balanceOf(_account);
        _pairInfo.account_token1_balance = IERC20(token_1).balanceOf(_account);
        _pairInfo.account_gauge_balance = accountGaugeLPAmount;
        _pairInfo.account_gauge_earned = earned;

        // votes
        _pairInfo.votes = voterV3.weights(_pair);     
    }

    // read all the bribe available for a pair
    function _getBribes(address pair) internal view returns(Bribes[] memory){

        address _gaugeAddress;
        address _bribeAddress;

        Bribes[] memory _tempReward = new Bribes[](2);

        // get external
        _gaugeAddress = voter.gauges(pair);

        {
            if(address(_gaugeAddress) != address(0)){
                
                _bribeAddress = voter.external_bribes(_gaugeAddress);
                _tempReward[0] = _getNextEpochRewards(_bribeAddress);
                
                // get internal
                _bribeAddress = voter.internal_bribes(_gaugeAddress);
                _tempReward[1] = _getNextEpochRewards(_bribeAddress);
            }
        }

        return _tempReward;
            
    }

    function _getNextEpochRewards(address _bribeAddress) internal view returns(Bribes memory _rewards){
        uint totTokens = IBribeAPI(_bribeAddress).rewardsListLength();
        uint[] memory _amounts = new uint[](totTokens);
        address[] memory _tokens = new address[](totTokens);
        string[] memory _symbol = new string[](totTokens);
        uint[] memory _decimals = new uint[](totTokens);
        uint ts = IBribeAPI(_bribeAddress).getNextEpochStart();
        uint i = 0;
        address _token;
        IBribeAPI.Reward memory _reward;

        for(i; i < totTokens; i++){
            _token = IBribeAPI(_bribeAddress).rewardTokens(i);
            _tokens[i] = _token;
            _symbol[i] = IERC20(_token).symbol();
            _decimals[i] = IERC20(_token).decimals();
            _reward = IBribeAPI(_bribeAddress).rewardData(_token, ts);
            _amounts[i] = _reward.rewardsPerEpoch;
            
        }

        _rewards.bribeAddress = _bribeAddress;
        _rewards.tokens = _tokens;
        _rewards.amounts = _amounts;
        _rewards.symbols = _symbol;
        _rewards.decimals = _decimals;
    }

    function getCurrentFees(address _pair, address token_0, address token_1)  internal view returns(uint _tokenFees0, uint _tokenFees1, address _feesAddress) {
        Pair pair = Pair(_pair);  

        address feesAddress = pair.fees();
        uint tokenFees0 = IERC20(token_0).balanceOf(feesAddress);
        uint tokenFees1 = IERC20(token_1).balanceOf(feesAddress);

        return (tokenFees0, tokenFees1, feesAddress);
    }

    function getPairBribe(uint _amounts, uint _offset, address _pair) external view returns(pairBribeEpoch[] memory _pairEpoch){

        require(_amounts <= MAX_EPOCHS, 'too many epochs');

        _pairEpoch = new pairBribeEpoch[](_amounts);

        address _gauge = voter.gauges(_pair);
        if(_gauge == address(0)) return _pairEpoch;

        IBribeAPI bribe  = IBribeAPI(voter.external_bribes(_gauge));

        // check bribe and checkpoints exists
        if(address(0) == address(bribe)) return _pairEpoch;
        
      
        // scan bribes
        // get latest balance and epoch start for bribes
        uint _epochStartTimestamp = bribe.firstBribeTimestamp();

        // if 0 then no bribe created so far
        if(_epochStartTimestamp == 0){
            return _pairEpoch;
        }

        uint _supply;
        uint i = _offset;

        for(i; i < _offset + _amounts; i++){
            
            _supply            = bribe.totalSupplyAt(_epochStartTimestamp);
            _pairEpoch[i-_offset].epochTimestamp = _epochStartTimestamp;
            _pairEpoch[i-_offset].pair = _pair;
            _pairEpoch[i-_offset].totalVotes = _supply;
            _pairEpoch[i-_offset].bribes = _bribe(_epochStartTimestamp, address(bribe));
            
            _epochStartTimestamp += WEEK;

        }

    }

    function _bribe(uint _ts, address _br) internal view returns(tokenBribe[] memory _tb){

        IBribeAPI _wb = IBribeAPI(_br);
        uint tokenLen = _wb.rewardsListLength();

        _tb = new tokenBribe[](tokenLen);

        uint k;
        uint _rewPerEpoch;
        IERC20 _t;
        for(k = 0; k < tokenLen; k++){
            _t = IERC20(_wb.rewardTokens(k));
            IBribeAPI.Reward memory _reward = _wb.rewardData(address(_t), _ts);
            _rewPerEpoch = _reward.rewardsPerEpoch;
            if(_rewPerEpoch > 0){
                _tb[k].token = address(_t);
                _tb[k].symbol = _t.symbol();
                _tb[k].decimals = _t.decimals();
                _tb[k].amount = _rewPerEpoch;
            } else {
                _tb[k].token = address(_t);
                _tb[k].symbol = _t.symbol();
                _tb[k].decimals = _t.decimals();
                _tb[k].amount = 0;
            }
        }
    }


    function setOwner(address _owner) external {
        require(msg.sender == owner, 'not owner');
        require(_owner != address(0), 'zeroAddr');
        owner = _owner;
        emit Owner(msg.sender, _owner);
    }


    function setVoter(address _voter) external {
        require(msg.sender == owner, 'not owner');
        require(_voter != address(0), 'zeroAddr');
        address _oldVoter = address(voter);
        voter = IVoter(_voter);
        
        // update variable depending on voter
        pairFactory = IPairFactory(voter.factories()[0]);
        underlyingToken = IVotingEscrow(voter._ve()).token();

        emit Voter(_oldVoter, _voter);
    }

    function left(address _pair, address _token) external view returns(uint256 _rewPerEpoch){
        address _gauge = voter.gauges(_pair);
        IBribeAPI bribe  = IBribeAPI(voter.internal_bribes(_gauge));
        
        uint256 _ts = bribe.getEpochStart();
        IBribeAPI.Reward memory _reward = bribe.rewardData(_token, _ts);
        _rewPerEpoch = _reward.rewardsPerEpoch;
    
    }


}