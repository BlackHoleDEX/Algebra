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
import "./interfaces/IAuction.sol";
import "./interfaces/IGanesisPoolBase.sol";
import "./interfaces/ITokenHandler.sol";
import "./interfaces/IPermissionsRegistry.sol";
import "./interfaces/IGenesisPoolFactory.sol";
import './interfaces/IGenesisPool.sol';
import './interfaces/IAuctionFactory.sol';

interface IBaseV1Factory {
    function isPair(address pair) external view returns (bool);
    function getPair(address tokenA, address token, bool stable) external view returns (address);
    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair);
    function setGenesisPool(address _genesisPool) external;
    function setGenesisStatus(address _pair, bool status) external;
}

contract GenesisPoolManager is IGanesisPoolBase, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    uint256 public MIN_DURATION = 7 days; 
    uint256 public MIN_THRESHOLD = 50 * 10 ** 2; 
    uint256 public MATURITY_TIME = 90 days;

    address public _epochController;
    address public _dutchAuction;
    address public _permissionRegistory;
    address public _router;
    IBaseV1Factory public _pairFactory;
    IVoterV3 public _voter;
    ITokenHandler public _tokenManager;

    IGenesisPoolFactory public genesisFactory;
    IAuctionFactory public auctionFactory;

    using SafeERC20 for IERC20;

    mapping(address => mapping(address => bool)) public whiteListedTokensToUser; 
    mapping(address => TokenAllocation) public allocationsInfo;
    mapping(address => TokenIncentiveInfo) public incentivesInfo;
    mapping(address => GenesisInfo) public genesisPoolsInfo;
    mapping(address => ProtocolInfo) public protocolsInfo;
    mapping(address => PoolStatus) public poolsStatus;
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(address => LiquidityPool) public liquidityPoolsInfo;

    address[] public proposedTokens;
    mapping(address => address[]) public depositers;

    event WhiteListedTokenToUser(address proposedToken, address tokenOwner);
    event DespositedToken(address genesisPool, address sender, uint256 amount);
    modifier Governance() {
        require(IPermissionsRegistry(_permissionRegistory).hasRole("GOVERNANCE",msg.sender), 'GOVERNANCE');
        _;
    }

    constructor() {}

    // function initialize(address router, address epochController, address voter, address pairFactory, address tokenHandler, address permissionRegistory) initializer  public {
    //     __Ownable_init();

    //     _dutchAuction = msg.sender;
    //     _epochController = epochController;
    //     _pairFactory = IBaseV1Factory(pairFactory);
    //     _router = router;
    //     _voter = IVoterV3(voter);
    //     _tokenManager = ITokenHandler(tokenHandler);
    //     _permissionRegistory = permissionRegistory;
    // }

    function initialize(address _genesisFactory, address _auctionFactory) initializer  public {
        __Ownable_init();

        genesisFactory = IGenesisPoolFactory(_genesisFactory);
        auctionFactory = IAuctionFactory(_auctionFactory);
    }

    function whiteListUserAndToken(address tokenOwner, address proposedToken) external Governance nonReentrant{
        whiteListedTokensToUser[proposedToken][tokenOwner] = true;
        emit WhiteListedTokenToUser(proposedToken, tokenOwner);
    }

    function depositNativeToken(address nativeToken, uint auction, GenesisInfo calldata genesisPoolInfo, ProtocolInfo calldata protocolInfo, TokenAllocation calldata allocationInfo) external nonReentrant returns(address genesisPool) {
        address _sender = msg.sender;
        require(whiteListedTokensToUser[nativeToken][_sender] || _sender == owner(), "!listed");
        require(allocationInfo.proposedNativeAmount > 0, "0 native");
        require(allocationInfo.proposedFundingAmount > 0, "0 funding");
        require(genesisFactory.getGenesisPool(nativeToken) == address(0), "exists");

        address _fundingToken = genesisPoolInfo.fundingToken;
        require(_tokenManager.isConnector(_fundingToken), "connector !=");
        bool _stable = protocolInfo.stable;
        require(_pairFactory.getPair(nativeToken, _fundingToken, _stable) == address(0), "existing pair");

        require(genesisPoolInfo.duration >= MIN_DURATION && genesisPoolInfo.threshold >= MIN_THRESHOLD && genesisPoolInfo.startPrice > 0, "genesis info");
        require(genesisPoolInfo.supplyPercent >= 0 && genesisPoolInfo.supplyPercent <= 100, "inavlid supplyPercent");
        
        require(protocolInfo.tokenAddress == nativeToken, "unequal protocol token");
        require(bytes(protocolInfo.tokenName).length > 0 && bytes(protocolInfo.tokenTicker).length > 0 && bytes(protocolInfo.protocolBanner).length > 0 && bytes(protocolInfo.protocolDesc).length > 0, "protocol info");

        genesisPool = genesisFactory.createGenesisPool(_sender, nativeToken, _fundingToken, auctionFactory.auctions(auction));
        require(genesisPool != address(0), "0x");

        assert(IERC20(nativeToken).transferFrom(_sender, genesisPool, allocationInfo.proposedNativeAmount));

        proposedTokens.push(nativeToken);
        IGenesisPool(genesisPool).setGenesisPoolInfo(genesisPoolInfo, protocolInfo, allocationInfo);
    }

    function rejectGenesisPool(address nativeToken) external Governance nonReentrant {
        require(nativeToken != address(0), "0x native");
        address genesisPool = genesisFactory.getGenesisPool(nativeToken);
        require(genesisPool != address(0), '0x pool');

        IGenesisPool(genesisPool).rejectPool();
        
    }

    function approveGenesisPool(address nativeToken) external Governance nonReentrant {
        require(nativeToken != address(0), "0x native");
        address genesisPool = genesisFactory.getGenesisPool(nativeToken);
        require(genesisPool != address(0), '0x pool');

        _tokenManager.whitelist(nativeToken);

        address pairAddress = _pairFactory.createPair(nativeToken, IGenesisPool(genesisPool).genesis().fundingToken, IGenesisPool(genesisPool).protocol().stable);
        _pairFactory.setGenesisStatus(pairAddress, true);

        IGenesisPool(genesisPool).approvePool(pairAddress);
    }

    function depositToken(address genesisPool, uint256 amount) external nonReentrant{
        require(amount > 0, "0 amt");
        require(genesisPool != address(0), "0x");

        bool preLaunchPool = IGenesisPool(genesisPool).depositToken(msg.sender, amount);

        if(preLaunchPool){
            _preLaunchPool(genesisPool);
        }

        emit DespositedToken(genesisPool, msg.sender, amount);
    }


    // at epoch flip, PRE_LISTING -> PRE_LAUNCH (condition met) , PRE_LAUNCH_DDEPOSIT_DISBALED -> LAUNCH or PARTIALLY_LAUNCH
    function checkAtEpochFlip() external nonReentrant{
        require(_epochController == msg.sender, "invalid access");

        uint256 _proposedTokensCnt = proposedTokens.length;
        uint256 i;
        address _genesisPool;
        PoolStatus _poolStatus;
        for(i = 0; i < _proposedTokensCnt; i++){
            _genesisPool = genesisFactory.getGenesisPool(proposedTokens[i]);
            _poolStatus = IGenesisPool(_genesisPool).poolStatus();

            if(_poolStatus == PoolStatus.PRE_LISTING && IGenesisPool(_genesisPool).eligbleForPreLaunchPool()){
                _preLaunchPool(_genesisPool);
            }else if(_poolStatus == PoolStatus.PRE_LAUNCH_DEPOSIT_DISABLED){
                _launchPool(_genesisPool);
            }
        }
    }


    function _preLaunchPool(address genesisPool) internal {
        address _poolAddress = IGenesisPool(genesisPool).liquidityPool().pairAddress;
        (address _gauge, address _internal_bribe, address _external_bribe) = _voter.createGauge(_poolAddress, 0);

        IGenesisPool(genesisPool).transferIncentives(_gauge, _external_bribe, _internal_bribe);
    }

    function _launchPool(address _genesisPool) internal {
        if(IGenesisPool(_genesisPool).eligbleForCompleteLaunch()){
            _completelyLaunchPool(_genesisPool);
        }else{
            _partiallyLaunchPool(_genesisPool);
        }
    }

    function _completelyLaunchPool(address _genesisPool) internal {
        (address nativeToken, address fundingToken, uint256 nativeDesired, uint256 fundingDesired, 
        address poolAddress, address gaugeAddress, bool stable) = IGenesisPool(_genesisPool).setLaunchStatus(PoolStatus.PARTIALLY_LAUNCHED);

        _addLiquidityAndDistribute(_genesisPool, nativeToken, fundingToken, nativeDesired, fundingDesired, poolAddress, gaugeAddress, stable);
    }


    function _partiallyLaunchPool(address _genesisPool) internal {
        (address nativeToken, address fundingToken, uint256 nativeDesired, uint256 fundingDesired, 
        address poolAddress, address gaugeAddress, bool stable) = IGenesisPool(_genesisPool).setLaunchStatus(PoolStatus.PARTIALLY_LAUNCHED);

        _addLiquidityAndDistribute(_genesisPool, nativeToken, fundingToken, nativeDesired, fundingDesired, poolAddress, gaugeAddress, stable);
    }

    function _addLiquidityAndDistribute(address _genesisPool, address nativeToken, address fundingToken, uint256 nativeDesired, uint256 fundingDesired, 
        address poolAddress, address gaugeAddress, bool stable) internal {

        _pairFactory.setGenesisStatus(poolAddress, false);
        IGenesisPool(_genesisPool).approveTokens(_router);

        (, , uint liquidity) = IRouter01(_router).addLiquidity(nativeToken, fundingToken, stable, nativeDesired, fundingDesired, 0, 0, address(this), block.timestamp + 100);

        (address[] memory _accounts, uint256[] memory _amounts, address _tokenOwner) = IGenesisPool(_genesisPool).getLPTokensShares(liquidity);

        IERC20(poolAddress).approve(gaugeAddress, liquidity);
        IGauge(gaugeAddress).depositsForGenesis(_accounts, _amounts, _tokenOwner, block.timestamp + MATURITY_TIME, liquidity);
    }
    
    // before 3 hrs
    function checkBeforeEpochFlip() external nonReentrant{
        require(_epochController == msg.sender, "invalid access");

        uint256 _proposedTokensCnt = proposedTokens.length;
        uint256 i;
        address _proposedToken;
        PoolStatus _poolStatus;
        GenesisInfo storage _genesisPool;
        TokenAllocation storage _tokenAllocation;
        uint256 targetFundingAmount;
        uint _endTime;

        for(i = 0; i < _proposedTokensCnt; i++){
            _proposedToken = proposedTokens[i];
            _poolStatus = poolsStatus[_proposedToken];

            if(_poolStatus == PoolStatus.PRE_LISTING){
                _genesisPool = genesisPoolsInfo[_proposedToken];
                _endTime = _genesisPool.startTime + _genesisPool.duration;
                _tokenAllocation = allocationsInfo[_proposedToken];
                targetFundingAmount = (_tokenAllocation.proposedFundingAmount * _genesisPool.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls

                if(BlackTimeLibrary.isLastEpoch(block.timestamp, _endTime) && targetFundingAmount < _tokenAllocation.allocatedFundingAmount) {
                    _pairFactory.setGenesisStatus(liquidityPoolsInfo[_proposedToken].pairAddress, false);
                    poolsStatus[_proposedToken] = PoolStatus.NOT_QUALIFIED;
                    _tokenAllocation.refundableNativeAmount = _tokenAllocation.proposedNativeAmount;
                }
            }
            else if(_poolStatus == PoolStatus.PRE_LAUNCH){
                poolsStatus[_proposedToken] = PoolStatus.PRE_LAUNCH_DEPOSIT_DISABLED;
            }
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

    function setEpochController(address epochController) external Governance {
        _epochController = epochController;
    }

    function setDutchAuction(address dutchAuction) external Governance {
        _dutchAuction = dutchAuction;
    }

    function setMinimumDuration(uint256 _duration) external Governance {
        MIN_DURATION = _duration;
    }

    function setMinimumThreshold(uint256 _threshold) external Governance {
        MIN_THRESHOLD = _threshold;
    }

    function setMaturityTime(uint256 _maturityTime) external Governance {
        MATURITY_TIME = _maturityTime;
    }
}