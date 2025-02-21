// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {BlackTimeLibrary} from "./libraries/BlackTimeLibrary.sol";
import {IGenesisPoolManager} from "./interfaces/IGenesisPoolManager.sol";

contract GenesisPoolManager is OwnableUpgradeable, ReentrancyGuardUpgradeable {

    uint256 internal constant WEEK = 7 days; 
    uint256 internal constant MIN_DURATION = 14 days; 
    uint256 internal constant MIN_THRESHOLD = 50 * 10 ** 2; 

    address public team; 
    address public _epochController;

    struct TokenAllocation {
        address tokenOwner;
        uint256 proposedNativeAmount;
        uint256 proposedFundingAmount;
        uint256 allocatedNativeAmount;
        uint256 allocatedFundingAmount;

        uint256 refundableNativeAmount;
    }

    struct TokenIncentiveInfo{
        address tokenOwner;
        address[] incentivesToken;
        uint256[] incentivesAmount;
    }

    struct GenesisPool{
        address fundingToken;
        uint256 duration;
        uint8 threshold; // multiplied by 100 to support 2 decimals
        uint256 supplyPercent; 
        uint256 startPrice;
        uint256 startTime;
    }

    struct ProtocolInfo {
        address tokenAddress;
        string tokenName;
        string tokenTicker;
        string protocolDesc;
        string protocolBanner;
        string tokenIcon;
    }

    enum PoolStatus{
        DEFAULT,
        TOKEN_ALLOCATED,
        INCENTIVES_ADDED,
        APPLIED,
        PRE_LISTING,
        PRE_LAUNCH,
        PRE_LAUNCH_DEPOSIT_DISABLED,
        LAUNCH,
        PARTIALLY_LAUNCHED,
        NOT_QUALIFIED,
        MAXED_OUT
    }

    using SafeERC20 for IERC20;

    mapping(address => mapping(address => bool)) public whiteListedTokensToUser; 
    mapping(address => TokenAllocation) public allocationsInfo;
    mapping(address => TokenIncentiveInfo) public incentivesInfo;
    mapping(address => GenesisPool) public genesisPoolsInfo;
    mapping(address => ProtocolInfo) public protocolsInfo;
    mapping(address => PoolStatus) public poolsStatus;
    mapping(address => mapping(address => uint256)) public userDeposits;

    address[] public proposedTokens;
    mapping(address => address[]) public depositers;

    event AddedTokenAllocation(address proposedToken, uint256 proposedNativeAmount, uint proposedFundingAmount);
    event AddedIncentives(address proposedToken, address[] incentivesToken, uint256[] incentivesAmount);
    event OnBoardedGenesisPool(address proposedToken);
    event ApprovedGenesisPool(address proposedToken);
    event DespositedToken(address proposedToken, address fundingToken, uint256 amount);

    constructor() {}

    function initialize() initializer  public {
        __Ownable_init();

        team = msg.sender;
        _epochController = msg.sender;
    }

    function addTokenAllocation(address proposedToken, uint256 proposedNativeAmount, uint proposedFundingAmount) external nonReentrant{
        address _tokenOwner = msg.sender;
        require(whiteListedTokensToUser[proposedToken][_tokenOwner], "not whitelisted");
        require(poolsStatus[proposedToken] == PoolStatus.DEFAULT, "already token allocated");
        require(proposedNativeAmount > 0, "proposed native token 0");
        require(proposedFundingAmount > 0, "proposed funding token 0");

        TokenAllocation memory _tokenAllocation = allocationsInfo[proposedToken];

        _tokenAllocation.tokenOwner = _tokenOwner;
        _tokenAllocation.proposedNativeAmount = proposedNativeAmount;
        _tokenAllocation.proposedFundingAmount = proposedFundingAmount;

        allocationsInfo[proposedToken] = _tokenAllocation;
        poolsStatus[proposedToken] = PoolStatus.TOKEN_ALLOCATED;

        emit AddedTokenAllocation(proposedToken, proposedNativeAmount, proposedFundingAmount);
    }

    function addIncentives(address proposedToken, address[] calldata incentivesToken, uint256[] calldata incentivesAmount) external nonReentrant{
        address _tokenOwner = msg.sender;
        require(incentivesToken.length > 0, "incentive length 0");
        require(incentivesToken.length == incentivesAmount.length, "length mismatch");
        require(whiteListedTokensToUser[proposedToken][_tokenOwner], "not whitelisted");
        require(poolsStatus[proposedToken] == PoolStatus.TOKEN_ALLOCATED, "token not allocated");

        uint256 _incentivesCount = incentivesToken.length;
        uint256 i = 0;
        for(i = 0; i < _incentivesCount; i++){
            require(incentivesToken[i] != address(0), "invalid incentive token address");
            require(incentivesAmount[i] > 0, "invalid incentive amount");
        }

        i = 0;
        for(i = 0; i < _incentivesCount; i++){
            assert(IERC20(incentivesToken[i]).transferFrom(_tokenOwner, address(this), incentivesAmount[i]));
        }

        TokenIncentiveInfo memory _tokenIncentiveInfo = incentivesInfo[proposedToken];

        _tokenIncentiveInfo.tokenOwner = _tokenOwner;
        _tokenIncentiveInfo.incentivesToken = incentivesToken;
        _tokenIncentiveInfo.incentivesAmount = incentivesAmount;

        incentivesInfo[proposedToken] = _tokenIncentiveInfo;
        poolsStatus[proposedToken] = PoolStatus.INCENTIVES_ADDED;

        emit AddedIncentives(proposedToken, incentivesToken, incentivesAmount);
    }


    function onboardGenesisPool(address proposedToken, GenesisPool calldata genesisPool, ProtocolInfo calldata protocolInfo) external nonReentrant {
        address _tokenOwner = msg.sender;
        require(whiteListedTokensToUser[proposedToken][_tokenOwner], "not whitelisted");
        require(poolsStatus[proposedToken] == PoolStatus.INCENTIVES_ADDED, "incentives not added");

        require(genesisPool.fundingToken != address(0), "invalid fundingToken token");
        require(genesisPool.duration >= MIN_DURATION, "minimum duration");
        require(genesisPool.threshold >= MIN_THRESHOLD, "minimum threshold");
        require(genesisPool.supplyPercent >= 0 && genesisPool.supplyPercent <= 100, "inavlid supplyPercent");
        require(genesisPool.startPrice > 0, "invalid startPrice");
        
        require(protocolInfo.tokenAddress != address(0), "invalid protocol token");
        require(bytes(protocolInfo.tokenName).length > 0, "invalid protocol name");
        require(bytes(protocolInfo.tokenTicker).length > 0, "invalid protocol ticker");
        require(bytes(protocolInfo.tokenName).length > 0, "invalid protocol deec");
        require(bytes(protocolInfo.protocolBanner).length > 0, "invalid protocol banner");
        require(bytes(protocolInfo.protocolDesc).length > 0, "invalid protocol desc");

        TokenAllocation memory _tokenAllocation = allocationsInfo[proposedToken];

        assert(IERC20(protocolInfo.tokenAddress).transferFrom(_tokenOwner, address(this), _tokenAllocation.proposedNativeAmount));

        _tokenAllocation.allocatedNativeAmount = 0;
        _tokenAllocation.allocatedFundingAmount = 0;

        allocationsInfo[proposedToken] = _tokenAllocation;

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

    function approveGenesisPool(address proposedToken) external nonReentrant {
        require(team == msg.sender, "invalid owenr");

        poolsStatus[proposedToken] = PoolStatus.PRE_LISTING;

        emit ApprovedGenesisPool(proposedToken);
    }

    function depositToken(address proposedToken, address fundingToken, uint256 amount) external nonReentrant{
        require(amount > 0, "invalid amount");
        require(proposedToken != address(0), "invalid proposed token");

        PoolStatus _poolStatus = poolsStatus[proposedToken];
        require(_poolStatus == PoolStatus.PRE_LISTING || _poolStatus == PoolStatus.PRE_LAUNCH, "invalid pool status");

        GenesisPool memory _genesisPool = genesisPoolsInfo[proposedToken];
        require(_genesisPool.fundingToken == fundingToken, "invalid funding token");

        TokenAllocation memory _tokenAllocation = allocationsInfo[proposedToken];
        uint256 _amount = _tokenAllocation.proposedFundingAmount - _tokenAllocation.allocatedFundingAmount;
        _amount = _amount < amount ? _amount : amount;

        address _spender = msg.sender;

        assert(IERC20(fundingToken).transferFrom(_spender, address(this), _amount));

        if(userDeposits[proposedToken][_spender] == 0){
            depositers[proposedToken].push(_spender);
        }

        userDeposits[proposedToken][_spender] = userDeposits[proposedToken][_spender] + _amount;

        _tokenAllocation.allocatedFundingAmount += _amount;
        _tokenAllocation.allocatedNativeAmount += amount; // need to change it, should be based on price
        allocationsInfo[proposedToken] = _tokenAllocation;

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

    function _checkAndPreLaunchPool(address proposedToken) internal nonReentrant{
        GenesisPool memory _genesisPool = genesisPoolsInfo[proposedToken];
        uint _endTime = _genesisPool.startPrice + _genesisPool.duration;
        TokenAllocation memory _tokenAllocation = allocationsInfo[proposedToken];
        uint256 targetFundingAmount = (_tokenAllocation.proposedFundingAmount * _genesisPool.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls

        if(_endTime - WEEK < block.timestamp && block.timestamp < _endTime && _tokenAllocation.allocatedFundingAmount >= targetFundingAmount) {
            // generate pool & gauge, add the incentives 

            poolsStatus[proposedToken] = PoolStatus.PRE_LAUNCH;
        }
    }

    function _launchPool(address proposedToken) internal nonReentrant{
        TokenAllocation memory _tokenAllocation = allocationsInfo[proposedToken];
        GenesisPool memory _genesisPool = genesisPoolsInfo[proposedToken];
        uint256 targetFundingAmount = (_tokenAllocation.proposedFundingAmount * _genesisPool.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls

        if(targetFundingAmount == _tokenAllocation.allocatedFundingAmount){
            _completelyLaunchPool(proposedToken);
        }else{
            _partiallyLaunchPool(proposedToken);
        }
    }

    function _completelyLaunchPool(address proposedToken) internal nonReentrant{}


    function _partiallyLaunchPool(address proposedToken) internal nonReentrant{}
    
    // before 3 hrs
    function checkBeforeEpochFlip() external nonReentrant{
        require(_epochController == msg.sender, "invalid access");

        uint256 _proposedTokensCnt = proposedTokens.length;
        uint256 i;
        address _proposedToken;
        PoolStatus _poolStatus;
        GenesisPool memory _genesisPool;
        TokenAllocation memory _tokenAllocation;
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
                    poolsStatus[_proposedToken] = PoolStatus.NOT_QUALIFIED;
                }
            }
            else if(_poolStatus == PoolStatus.PRE_LAUNCH){
                poolsStatus[_proposedToken] = PoolStatus.NOT_QUALIFIED;
            }
        }
    }

    function claimableUnallocatedAmount(address proposedToken) public view returns(PoolStatus, address, uint256){

        if(proposedToken == address(0)){
            return (PoolStatus.DEFAULT, address(0), 0);
        }
        
        PoolStatus _poolStatus = poolsStatus[proposedToken];
        TokenAllocation memory _tokenAllocation = allocationsInfo[proposedToken];

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

        TokenAllocation memory _tokenAllocation = allocationsInfo[proposedToken];
        uint256 _amount;

        if(_poolStatus == PoolStatus.PARTIALLY_LAUNCHED){
            if(msg.sender == _tokenAllocation.tokenOwner){
                _amount = _tokenAllocation.refundableNativeAmount;
                _tokenAllocation.refundableNativeAmount = 0;
                allocationsInfo[proposedToken] = _tokenAllocation;

                if(_amount > 0){
                    assert(IERC20(proposedToken).transfer(msg.sender, _amount));
                }
            } 
        }else if(_poolStatus == PoolStatus.NOT_QUALIFIED){
            if(msg.sender == _tokenAllocation.tokenOwner){
                _amount = _tokenAllocation.refundableNativeAmount;
                _tokenAllocation.refundableNativeAmount = 0;
                allocationsInfo[proposedToken] = _tokenAllocation;

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

        PoolStatus _poolStatus = poolsStatus[proposedToken];
        TokenAllocation memory _tokenAllocation = allocationsInfo[proposedToken];

        if(_poolStatus == PoolStatus.NOT_QUALIFIED && msg.sender == _tokenAllocation.tokenOwner){
            TokenIncentiveInfo memory _incentiveInfo = incentivesInfo[proposedToken];
            tokens = _incentiveInfo.incentivesToken;
            amounts = _incentiveInfo.incentivesAmount;

            return (tokens, amounts);
        }

        return (tokens, amounts);
    }

    function claimIncentives(address proposedToken) external nonReentrant{
        require(proposedToken != address(0), "invalid address");
        PoolStatus _poolStatus = poolsStatus[proposedToken];
        require(_poolStatus == PoolStatus.NOT_QUALIFIED, "invalid status");
        TokenAllocation memory _tokenAllocation = allocationsInfo[proposedToken];
        require(msg.sender == _tokenAllocation.tokenOwner, "invalid onwer");

        TokenIncentiveInfo memory _incentiveInfo = incentivesInfo[proposedToken];
        uint256 _incentivesCnt = _incentiveInfo.incentivesToken.length;
        uint256 i;

        for(i = 0; i < _incentivesCnt; i++){
            assert(IERC20(_incentiveInfo.incentivesToken[i]).transfer(msg.sender, _incentiveInfo.incentivesAmount[i]));
            _incentiveInfo.incentivesAmount[i] = 0;
        }

        incentivesInfo[proposedToken] = _incentiveInfo;
    }
}