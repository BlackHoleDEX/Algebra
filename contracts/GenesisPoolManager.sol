// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {BlackTimeLibrary} from "./libraries/BlackTimeLibrary.sol";
import "./interfaces/IGenesisPoolManager.sol";
import './interfaces/IRouter01.sol';
import "./interfaces/IVoterV3.sol";
import "./interfaces/IBribe.sol";
import "./interfaces/IGauge.sol";
import "./interfaces/IDutchAuction.sol";
import "./GanesisPoolBase.sol";


interface IBaseV1Factory {
    function isPair(address pair) external view returns (bool);
    function getPair(address tokenA, address token, bool stable) external view returns (address);
    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair);
    function setGenesisPool(address _genesisPool) external;
    function setGenesisStatus(address _pair, bool status) external;
}

contract GenesisPoolManager is GanesisPoolBase, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    uint256 internal constant WEEK = 7 days; 
    uint256 internal constant MIN_DURATION = 7 days; 
    uint256 internal constant MIN_THRESHOLD = 50 * 10 ** 2; 
    uint256 internal constant MATURITY_TIME = 90 days;

    address public _team; 
    address public _owner;
    address public _epochController;
    address public _dutchAuction;
    IBaseV1Factory public _pairFactory;
    IRouter01 public _router;
    IVoterV3 public _voter;

    using SafeERC20 for IERC20;

    mapping(address => mapping(address => bool)) public whiteListedTokensToUser; 
    mapping(address => TokenAllocation) public allocationsInfo;
    mapping(address => TokenIncentiveInfo) public incentivesInfo;
    mapping(address => GenesisPool) public genesisPoolsInfo;
    mapping(address => ProtocolInfo) public protocolsInfo;
    mapping(address => PoolStatus) public poolsStatus;
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(address => LiquidityPool) public liquidityPoolsInfo;

    address[] public proposedTokens;
    mapping(address => address[]) public depositers;

    mapping(address => bool) internal isIncentiveToken;
    address[] internal incentiveTokens;

    event AddedTokenAllocation(address proposedToken, uint256 proposedNativeAmount, uint proposedFundingAmount);
    event AddedIncentives(address proposedToken, address[] incentivesToken, uint256[] incentivesAmount);
    event OnBoardedGenesisPool(address proposedToken);
    event ApprovedGenesisPool(address proposedToken);
    event DespositedToken(address proposedToken, address fundingToken, uint256 amount);

    constructor() {}

    function initialize(address router, address epochController, address voter, address pairFactory) initializer  public {
        __Ownable_init();

        _team = msg.sender;
        _owner = msg.sender;
        _dutchAuction = msg.sender;
        _epochController = epochController;
        _pairFactory = IBaseV1Factory(pairFactory);
        _router = IRouter01(router);
        _voter = IVoterV3(voter);
    }

    function whiteListUserAndToken(address tokenOwner, address proposedToken) external nonReentrant{
        require(_team == msg.sender, "invalid access");
        whiteListedTokensToUser[proposedToken][tokenOwner] = true;
    }

    function addTokenAllocation(address proposedToken, address fundingToken, bool stable, uint256 proposedNativeAmount, uint proposedFundingAmount) external nonReentrant{
        address _sender = msg.sender;
        require(whiteListedTokensToUser[proposedToken][_sender] || _sender == _team, "not whitelisted");
        require(_pairFactory.getPair(proposedToken, fundingToken, stable) == address(0), "existing pair");
        require(poolsStatus[proposedToken] == PoolStatus.DEFAULT, "already token allocated");
        require(proposedNativeAmount > 0, "proposed native token 0");
        require(proposedFundingAmount > 0, "proposed funding token 0");

        TokenAllocation storage _tokenAllocation = allocationsInfo[proposedToken];

        _tokenAllocation.tokenOwner = _sender;
        _tokenAllocation.proposedNativeAmount = proposedNativeAmount;
        _tokenAllocation.proposedFundingAmount = proposedFundingAmount;

        poolsStatus[proposedToken] = PoolStatus.TOKEN_ALLOCATED;

        emit AddedTokenAllocation(proposedToken, proposedNativeAmount, proposedFundingAmount);
    }

    function addIncentives(address proposedToken, address fundingToken, bool stable, address[] calldata incentivesToken, uint256[] calldata incentivesAmount) external nonReentrant{
        address _sender = msg.sender;
        require(incentivesToken.length > 0, "incentive length 0");
        require(incentivesToken.length == incentivesAmount.length, "length mismatch");
        require(whiteListedTokensToUser[proposedToken][_sender] || _sender == _team, "not whitelisted");
        require(_pairFactory.getPair(proposedToken, fundingToken, stable) == address(0), "existing pair");
        require(poolsStatus[proposedToken] == PoolStatus.TOKEN_ALLOCATED, "token not allocated");

        uint256 _incentivesCount = incentivesToken.length;
        uint256 i = 0;
        for(i = 0; i < _incentivesCount; i++){
            require(incentivesToken[i] != address(0), "invalid incentive token address");
            require(incentivesAmount[i] > 0, "invalid incentive amount");

            if(incentivesToken[i] == proposedToken) continue;

            require(isIncentiveToken[incentivesToken[i]], "incentive not whitelisted");
        }

        i = 0;
        for(i = 0; i < _incentivesCount; i++){
            assert(IERC20(incentivesToken[i]).transferFrom(_sender, address(this), incentivesAmount[i]));
        }

        TokenIncentiveInfo storage _tokenIncentiveInfo = incentivesInfo[proposedToken];

        _tokenIncentiveInfo.tokenOwner = _sender;
        _tokenIncentiveInfo.incentivesToken = incentivesToken;
        _tokenIncentiveInfo.incentivesAmount = incentivesAmount;

        poolsStatus[proposedToken] = PoolStatus.INCENTIVES_ADDED;

        emit AddedIncentives(proposedToken, incentivesToken, incentivesAmount);
    }


    function onboardGenesisPool(address proposedToken, GenesisPool calldata genesisPool, ProtocolInfo calldata protocolInfo) external nonReentrant {
        address _sender = msg.sender;
        require(whiteListedTokensToUser[proposedToken][_sender] || _sender == _team, "not whitelisted");
        require(poolsStatus[proposedToken] == PoolStatus.INCENTIVES_ADDED, "incentives not added");
        
        require(isIncentiveToken[genesisPool.fundingToken], "fundingToken not whitelisted");

        require(_pairFactory.getPair(proposedToken, genesisPool.fundingToken, protocolInfo.stable) == address(0), "existing pair");

        require(genesisPool.duration >= MIN_DURATION, "minimum duration");
        require(genesisPool.threshold >= MIN_THRESHOLD, "minimum threshold");
        require(genesisPool.supplyPercent >= 0 && genesisPool.supplyPercent <= 100, "inavlid supplyPercent");
        require(genesisPool.startPrice > 0, "invalid startPrice");
        
        require(protocolInfo.tokenAddress == proposedToken, "unequal protocol token");
        require(bytes(protocolInfo.tokenName).length > 0, "invalid protocol name");
        require(bytes(protocolInfo.tokenTicker).length > 0, "invalid protocol ticker");
        require(bytes(protocolInfo.protocolBanner).length > 0, "invalid protocol banner");
        require(bytes(protocolInfo.protocolDesc).length > 0, "invalid protocol desc");

        TokenAllocation storage _tokenAllocation = allocationsInfo[proposedToken];

        assert(IERC20(protocolInfo.tokenAddress).transferFrom(_sender, address(this), _tokenAllocation.proposedNativeAmount));

        _tokenAllocation.allocatedNativeAmount = 0;
        _tokenAllocation.allocatedFundingAmount = 0;
        _tokenAllocation.refundableNativeAmount = 0;

        GenesisPool memory _genesisPool = genesisPoolsInfo[proposedToken];
        _genesisPool = genesisPool;
        _genesisPool.duration = ((_genesisPool.duration) / WEEK) * WEEK;
        _genesisPool.startTime = BlackTimeLibrary.epochNext(block.timestamp);
        genesisPoolsInfo[proposedToken] = _genesisPool;

        ProtocolInfo memory _protocolInfo = protocolsInfo[proposedToken];
        _protocolInfo = protocolInfo;
        protocolsInfo[proposedToken] = _protocolInfo;

        poolsStatus[proposedToken] = PoolStatus.APPLIED;
        proposedTokens.push(proposedToken);

        emit OnBoardedGenesisPool(proposedToken);
    }

    function disapproveGenesisPool(address proposedToken) external nonReentrant {
        require(_team == msg.sender, "invalid owenr");

        poolsStatus[proposedToken] = PoolStatus.NOT_QUALIFIED;
        TokenAllocation storage _tokenAllocation = allocationsInfo[proposedToken];
        _tokenAllocation.refundableNativeAmount = _tokenAllocation.proposedFundingAmount;
    }

    function approveGenesisPool(address proposedToken) external nonReentrant {
        require(_team == msg.sender, "invalid owenr");
        require(proposedToken != address(0), "0 address");

        _voter.whitelist(proposedToken);

        LiquidityPool storage _liquidityPool = liquidityPoolsInfo[proposedToken];
        _liquidityPool.pairAddress = _pairFactory.createPair(proposedToken, genesisPoolsInfo[proposedToken].fundingToken, protocolsInfo[proposedToken].stable);
        _pairFactory.setGenesisStatus(_liquidityPool.pairAddress, true);

        poolsStatus[proposedToken] = PoolStatus.PRE_LISTING;

        emit ApprovedGenesisPool(proposedToken);
    }

    function depositToken(address proposedToken, address fundingToken, uint256 amount) external nonReentrant{
        require(amount > 0, "invalid amount");
        require(proposedToken != address(0), "invalid proposed token");

        PoolStatus _poolStatus = poolsStatus[proposedToken];
        require(_poolStatus == PoolStatus.PRE_LISTING || _poolStatus == PoolStatus.PRE_LAUNCH, "invalid pool status");

        require(genesisPoolsInfo[proposedToken].fundingToken == fundingToken, "invalid funding token");

        TokenAllocation storage _tokenAllocation = allocationsInfo[proposedToken];
        uint256 _amount = _tokenAllocation.proposedFundingAmount - _tokenAllocation.allocatedFundingAmount;
        _amount = _amount < amount ? _amount : amount;

        address _spender = msg.sender;

        assert(IERC20(fundingToken).transferFrom(_spender, address(this), _amount));

        if(userDeposits[proposedToken][_spender] == 0){
            depositers[proposedToken].push(_spender);
        }

        userDeposits[proposedToken][_spender] = userDeposits[proposedToken][_spender] + _amount;

        _tokenAllocation.allocatedFundingAmount += _amount;
        _tokenAllocation.allocatedNativeAmount += _getProtcolTokenAmount(proposedToken, amount, _tokenAllocation);

        if(_poolStatus == PoolStatus.PRE_LISTING){
            _checkAndPreLaunchPool(proposedToken);
        }

        emit DespositedToken(proposedToken, _spender, _amount);
    }


    // at epoch flip, PRE_LISTING -> PRE_LAUNCH (condition met) , PRE_LAUNCH_DDEPOSIT_DISBALED -> LAUNCH or PARTIALLY_LAUNCH
    function checkAtEpochFlip() external nonReentrant{
        require(_epochController == msg.sender, "invalid access");

        uint256 _proposedTokensCnt = proposedTokens.length;
        uint256 i;
        address _proposedToken;
        PoolStatus _poolStatus;
        for(i = 0; i < _proposedTokensCnt; i++){
            _proposedToken = proposedTokens[i];
            _poolStatus = poolsStatus[_proposedToken];

            if(_poolStatus == PoolStatus.PRE_LISTING){
                _checkAndPreLaunchPool(_proposedToken);
            }else if(_poolStatus == PoolStatus.PRE_LAUNCH_DEPOSIT_DISABLED){
                _launchPool(_proposedToken);
            }
        }
    }

    function _checkAndPreLaunchPool(address proposedToken) internal {
        GenesisPool storage _genesisPool = genesisPoolsInfo[proposedToken];
        uint _endTime = _genesisPool.startPrice + _genesisPool.duration;
        TokenAllocation storage _tokenAllocation = allocationsInfo[proposedToken];
        uint256 targetFundingAmount = (_tokenAllocation.proposedFundingAmount * _genesisPool.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls

        if(_endTime - WEEK < block.timestamp && block.timestamp < _endTime && _tokenAllocation.allocatedFundingAmount >= targetFundingAmount) {

            LiquidityPool storage _liquidityPool = liquidityPoolsInfo[proposedToken];
            address _poolAddress = _liquidityPool.pairAddress;

            (address _gauge, address _internal_bribe, address _external_bribe) = _voter.createGauge(_poolAddress, 0);

            _liquidityPool.gaugeAddress = _gauge;
            _liquidityPool.internal_bribe = _internal_bribe;
            _liquidityPool.external_bribe = _external_bribe;

            TokenIncentiveInfo storage _incentiveInfo = incentivesInfo[proposedToken];
            uint256 i;
            uint256 _incentivesCnt = _incentiveInfo.incentivesToken.length;
            for(i = 0; i < _incentivesCnt; i++){
                if(_incentiveInfo.incentivesAmount[i] > 0)
                {
                    IBribe(_external_bribe).notifyRewardAmount(_incentiveInfo.incentivesToken[i], _incentiveInfo.incentivesAmount[i]);
                }
            }

            poolsStatus[proposedToken] = PoolStatus.PRE_LAUNCH;
        }
    }

    function _launchPool(address proposedToken) internal {
        TokenAllocation storage _tokenAllocation = allocationsInfo[proposedToken];
        GenesisPool storage _genesisPool = genesisPoolsInfo[proposedToken];
        uint256 targetFundingAmount = (_tokenAllocation.proposedFundingAmount * _genesisPool.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls

        if(targetFundingAmount == _tokenAllocation.allocatedFundingAmount){
            _completelyLaunchPool(proposedToken, _tokenAllocation, _genesisPool);
        }else{
            _partiallyLaunchPool(proposedToken, _tokenAllocation, _genesisPool);
        }
    }

    function _completelyLaunchPool(address proposedToken, TokenAllocation storage _tokenAllocation, GenesisPool storage _genesisPool) internal {
        LiquidityPool storage _liquidityPool = liquidityPoolsInfo[proposedToken];
        uint256 amountADesired = _tokenAllocation.allocatedNativeAmount;
        uint256 amountBDesired = _tokenAllocation.allocatedFundingAmount;

        _tokenAllocation.refundableNativeAmount = 0;

        _pairFactory.setGenesisStatus(_liquidityPool.pairAddress, false);
        (, , uint liquidity) = _router.addLiquidity(_genesisPool.fundingToken, proposedToken, protocolsInfo[proposedToken].stable, amountADesired, amountBDesired, 0, 0, address(this), block.timestamp + 100);

        address[] storage _depositers = depositers[proposedToken];
        uint256 _depositerscnt = _depositers.length;
        uint256[] memory _deposits = new uint256[](_depositerscnt);
        uint256 i;
        for(i = 0; i < _depositerscnt; i++){
            _deposits[i] = userDeposits[proposedToken][_depositers[i]];
        }

        (address[] memory _accounts, uint256[] memory _amounts) = IDutchAuction(_dutchAuction).getLPTokensShares(_depositers, _deposits, _tokenAllocation.tokenOwner, liquidity);

        IGauge(_liquidityPool.gaugeAddress).depositsForGenesis(_accounts, _amounts, _tokenAllocation.tokenOwner, block.timestamp + MATURITY_TIME);

        poolsStatus[proposedToken] = PoolStatus.LAUNCH;
    }


    function _partiallyLaunchPool(address proposedToken, TokenAllocation storage _tokenAllocation, GenesisPool storage _genesisPool) internal {
        LiquidityPool storage _liquidityPool = liquidityPoolsInfo[proposedToken];
        uint256 amountADesired = _tokenAllocation.allocatedNativeAmount;
        uint256 amountBDesired = _tokenAllocation.allocatedFundingAmount;

        _tokenAllocation.refundableNativeAmount = _tokenAllocation.proposedNativeAmount - _tokenAllocation.allocatedNativeAmount;

        _pairFactory.setGenesisStatus(_liquidityPool.pairAddress, false);
        (, , uint liquidity) = _router.addLiquidity(_genesisPool.fundingToken, proposedToken, false, amountADesired, amountBDesired, 0, 0, address(this), block.timestamp + 100);

        address[] storage _depositers = depositers[proposedToken];
        uint256 _depositerscnt = _depositers.length;
        uint256[] memory _deposits = new uint256[](_depositerscnt);
        uint256 i;
        for(i = 0; i < _depositerscnt; i++){
            _deposits[i] = userDeposits[proposedToken][_depositers[i]];
        }

        (address[] memory _accounts, uint256[] memory _amounts) = IDutchAuction(_dutchAuction).getLPTokensShares(_depositers, _deposits, _tokenAllocation.tokenOwner, liquidity);

        IGauge(_liquidityPool.gaugeAddress).depositsForGenesis(_accounts, _amounts, _tokenAllocation.tokenOwner, block.timestamp + MATURITY_TIME);

        poolsStatus[proposedToken] = PoolStatus.PARTIALLY_LAUNCHED;
    }
    
    // before 3 hrs
    function checkBeforeEpochFlip() external nonReentrant{
        require(_epochController == msg.sender, "invalid access");

        uint256 _proposedTokensCnt = proposedTokens.length;
        uint256 i;
        address _proposedToken;
        PoolStatus _poolStatus;
        GenesisPool storage _genesisPool;
        TokenAllocation storage _tokenAllocation;
        uint256 targetFundingAmount;
        uint _endTime;

        for(i = 0; i < _proposedTokensCnt; i++){
            _proposedToken = proposedTokens[i];
            _poolStatus = poolsStatus[_proposedToken];

            if(_poolStatus == PoolStatus.PRE_LISTING){
                _genesisPool = genesisPoolsInfo[_proposedToken];
                _endTime = _genesisPool.startPrice + _genesisPool.duration;
                _tokenAllocation = allocationsInfo[_proposedToken];
                targetFundingAmount = (_tokenAllocation.proposedFundingAmount * _genesisPool.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls

                if(_endTime - WEEK < block.timestamp && block.timestamp < _endTime && targetFundingAmount < _tokenAllocation.allocatedFundingAmount) {
                    _pairFactory.setGenesisStatus(liquidityPoolsInfo[_proposedToken].pairAddress, false);
                    poolsStatus[_proposedToken] = PoolStatus.NOT_QUALIFIED;
                    _tokenAllocation.refundableNativeAmount = _tokenAllocation.proposedNativeAmount;
                }
            }
            // else if(_poolStatus == PoolStatus.PRE_LAUNCH){
            //     poolsStatus[_proposedToken] = PoolStatus.NOT_QUALIFIED;
            // }
        }
    }

    function claimableUnallocatedAmount(address proposedToken) public view returns(PoolStatus, address, uint256){

        if(proposedToken == address(0)){
            return (PoolStatus.DEFAULT, address(0), 0);
        }
        
        PoolStatus _poolStatus = poolsStatus[proposedToken];
        TokenAllocation storage _tokenAllocation = allocationsInfo[proposedToken];

        if(_poolStatus == PoolStatus.PARTIALLY_LAUNCHED){
            if(msg.sender == _tokenAllocation.tokenOwner){
                return (_poolStatus, proposedToken, _tokenAllocation.refundableNativeAmount);
            } 
        }else if(_poolStatus == PoolStatus.NOT_QUALIFIED){
            if(msg.sender == _tokenAllocation.tokenOwner){
                return (_poolStatus, proposedToken, _tokenAllocation.refundableNativeAmount);
            }else{
                return (_poolStatus, genesisPoolsInfo[proposedToken].fundingToken, userDeposits[proposedToken][msg.sender]);
            }
        }
        
        return (PoolStatus.DEFAULT, address(0), 0);
    }

    function claimUnallocatedAmount(address proposedToken) external nonReentrant{
        require(proposedToken != address(0), "invalid address");
        PoolStatus _poolStatus = poolsStatus[proposedToken];
        require(_poolStatus == PoolStatus.NOT_QUALIFIED || _poolStatus == PoolStatus.PARTIALLY_LAUNCHED, "invalid status");

        TokenAllocation storage _tokenAllocation = allocationsInfo[proposedToken];
        uint256 _amount;

        if(_poolStatus == PoolStatus.PARTIALLY_LAUNCHED){
            if(msg.sender == _tokenAllocation.tokenOwner){
                _amount = _tokenAllocation.refundableNativeAmount;
                _tokenAllocation.refundableNativeAmount = 0;

                if(_amount > 0){
                    assert(IERC20(proposedToken).transfer(msg.sender, _amount));
                }
            } 
        }else if(_poolStatus == PoolStatus.NOT_QUALIFIED){
            if(msg.sender == _tokenAllocation.tokenOwner){
                _amount = _tokenAllocation.refundableNativeAmount;
                _tokenAllocation.refundableNativeAmount = 0;

                if(_amount > 0){
                    assert(IERC20(proposedToken).transfer(msg.sender, _amount));
                }
            }else{
                _amount = userDeposits[proposedToken][msg.sender];
                userDeposits[proposedToken][msg.sender] = 0;

                if(_amount > 0){
                    assert(IERC20(genesisPoolsInfo[proposedToken].fundingToken).transfer(msg.sender, _amount));
                }
            }
        }
    }

    function claimableIncentives(address proposedToken) public view returns(address[] memory tokens , uint256[] memory amounts){
        if(proposedToken == address(0)){
            return (tokens, amounts);
        }

        if(poolsStatus[proposedToken] == PoolStatus.NOT_QUALIFIED && msg.sender == allocationsInfo[proposedToken].tokenOwner){
            TokenIncentiveInfo storage _incentiveInfo = incentivesInfo[proposedToken];
            tokens = _incentiveInfo.incentivesToken;
            amounts = _incentiveInfo.incentivesAmount;

            return (tokens, amounts);
        }

        return (tokens, amounts);
    }

    function claimIncentives(address proposedToken) external nonReentrant{
        require(proposedToken != address(0), "invalid address");
        require(poolsStatus[proposedToken] == PoolStatus.NOT_QUALIFIED, "invalid status");
        require(msg.sender == allocationsInfo[proposedToken].tokenOwner, "invalid onwer");

        TokenIncentiveInfo storage _incentiveInfo = incentivesInfo[proposedToken];
        uint256 _incentivesCnt = _incentiveInfo.incentivesToken.length;
        uint256 i;
        uint _amount;

        for(i = 0; i < _incentivesCnt; i++){
            _amount = _incentiveInfo.incentivesAmount[i];
            _incentiveInfo.incentivesAmount[i] = 0;

            assert(IERC20(_incentiveInfo.incentivesToken[i]).transfer(msg.sender, _amount));
        }

        incentivesInfo[proposedToken] = _incentiveInfo;
    }

    function getProtcolTokenAmount(address proposedToken, uint256 depositAmount) external view returns (uint256){
        require(proposedToken != address(0), "invalid address");
        require(depositAmount > 0, "0 deposit amount");
        return _getProtcolTokenAmount(proposedToken, depositAmount, allocationsInfo[proposedToken]);
    }

    function _getProtcolTokenAmount(address proposedToken, uint256 depositAmount, TokenAllocation memory tokenAllocation) internal view returns (uint256){
        return IDutchAuction(_dutchAuction).getProtcolTokenAmount(genesisPoolsInfo[proposedToken].startPrice, depositAmount, tokenAllocation);
    }

    function setTeam(address team) external {
        require(_team == msg.sender || _owner == msg.sender, "invalid access");
        _team = team;
    }

    function setEpochController(address epochController) external {
        require(_team == msg.sender, "invalid access");
        _epochController = epochController;
    }

    function setDutchAuction(address dutchAuction) external {
        require(_team == msg.sender, "invalid access");
        _dutchAuction = dutchAuction;
    }

    function getIncentiveTokens() external view returns(address[] memory tokens) {
        return incentiveTokens;
    }

    function whitelistIncentivesTokens(address[] memory _tokens) public {
        require(_team == msg.sender, "invalid access");
        uint256 i = 0;
        for(i; i < _tokens.length; i++){
           _whitelistIncentivesToken(_tokens[i]);
        }
    }

    function whitelistIncentivesToken(address _token) public {
        require(_team == msg.sender, "invalid access");
        _whitelistIncentivesToken(_token);
    }

    function removeRewardToken(address _token) public {
        require(_team == msg.sender, "invalid access");

        if(isIncentiveToken[_token]){
            isIncentiveToken[_token] = false;
            uint256 length = incentiveTokens.length;
            uint256 i;
            for (i = 0; i < length; i++) {
                if (incentiveTokens[i] == _token) {
                    incentiveTokens[i] = incentiveTokens[length - 1]; 
                    incentiveTokens.pop(); 
                    return;
                }
            }
        }
    }

    function _whitelistIncentivesToken(address _rewardsToken) internal {
        if(!isIncentiveToken[_rewardsToken]){
            isIncentiveToken[_rewardsToken] = true;
            incentiveTokens.push(_rewardsToken);
        }
    }
}