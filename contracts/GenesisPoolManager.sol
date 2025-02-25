// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IGenesisPoolManager.sol";
import './interfaces/IRouter01.sol';
import "./interfaces/IVoterV3.sol";
import "./interfaces/IGauge.sol";
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

contract GenesisPoolManager is IGanesisPoolBase, IGenesisPoolManager, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    uint256 public MIN_DURATION = 7 days; 
    uint256 public MIN_THRESHOLD = 50 * 10 ** 2; 
    uint256 public MATURITY_TIME = 90 days;

    address public epochController;
    address public permissionRegistory;
    address public router;
    IBaseV1Factory public pairFactory;
    IVoterV3 public voter;
    ITokenHandler public _tokenManager;

    IGenesisPoolFactory public genesisFactory;
    IAuctionFactory public auctionFactory;

    using SafeERC20 for IERC20;

    mapping(address => mapping(address => bool)) public whiteListedTokensToUser; 
    address[] public proposedTokens;
    
    event WhiteListedTokenToUser(address proposedToken, address tokenOwner);
    event DespositedToken(address genesisPool, address sender, uint256 amount);
    modifier Governance() {
        require(IPermissionsRegistry(permissionRegistory).hasRole("GOVERNANCE",msg.sender), 'GOVERNANCE');
        _;
    }

    constructor() {}

    function initialize(address _epochController, address _router, address _permissionRegistory, address _voter, address _pairFactory, address _genesisFactory, address _auctionFactory) initializer  public {
        __Ownable_init();

        epochController = _epochController;
        router = _router;
        permissionRegistory = _permissionRegistory;
        voter = IVoterV3(_voter);
        pairFactory = IBaseV1Factory(_pairFactory);
        genesisFactory = IGenesisPoolFactory(_genesisFactory);
        auctionFactory = IAuctionFactory(_auctionFactory);
    }

    function whiteListUserAndToken(address tokenOwner, address proposedToken) external Governance nonReentrant{
        whiteListedTokensToUser[proposedToken][tokenOwner] = true;
        emit WhiteListedTokenToUser(proposedToken, tokenOwner);
    }

    function depositNativeToken(address nativeToken, uint auctionIndex, GenesisInfo calldata genesisPoolInfo, ProtocolInfo calldata protocolInfo, TokenAllocation calldata allocationInfo) external nonReentrant returns(address genesisPool) {
        address _sender = msg.sender;
        require(whiteListedTokensToUser[nativeToken][_sender] || _sender == owner(), "!listed");
        require(allocationInfo.proposedNativeAmount > 0, "0 native");
        require(allocationInfo.proposedFundingAmount > 0, "0 funding");
        require(genesisFactory.getGenesisPool(nativeToken) == address(0), "exists");

        address _fundingToken = genesisPoolInfo.fundingToken;
        require(_tokenManager.isConnector(_fundingToken), "connector !=");
        bool _stable = protocolInfo.stable;
        require(pairFactory.getPair(nativeToken, _fundingToken, _stable) == address(0), "existing pair");

        require(genesisPoolInfo.duration >= MIN_DURATION && genesisPoolInfo.threshold >= MIN_THRESHOLD && genesisPoolInfo.startPrice > 0, "genesis info");
        require(genesisPoolInfo.supplyPercent >= 0 && genesisPoolInfo.supplyPercent <= 100, "inavlid supplyPercent");
        
        require(protocolInfo.tokenAddress == nativeToken, "unequal protocol token");
        require(bytes(protocolInfo.tokenName).length > 0 && bytes(protocolInfo.tokenTicker).length > 0 && bytes(protocolInfo.protocolBanner).length > 0 && bytes(protocolInfo.protocolDesc).length > 0, "protocol info");

        address auction = auctionFactory.auctions(auctionIndex);
        auction = auction == address(0) ? auctionFactory.auctions(0) : auction;
        genesisPool = genesisFactory.createGenesisPool(_sender, nativeToken, _fundingToken, auction);
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

        address pairAddress = pairFactory.createPair(nativeToken, IGenesisPool(genesisPool).getGenesisInfo().fundingToken, IGenesisPool(genesisPool).getProtocolInfo().stable);
        pairFactory.setGenesisStatus(pairAddress, true);

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
        require(epochController == msg.sender, "invalid access");

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
        address _poolAddress = IGenesisPool(genesisPool).getLiquidityPoolInfo().pairAddress;
        (address _gauge, address _internal_bribe, address _external_bribe) = voter.createGauge(_poolAddress, 0);

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
        address poolAddress, address gaugeAddress, bool stable) = IGenesisPool(_genesisPool).setLaunchStatus(PoolStatus.LAUNCH);

        _addLiquidityAndDistribute(_genesisPool, nativeToken, fundingToken, nativeDesired, fundingDesired, poolAddress, gaugeAddress, stable);
    }


    function _partiallyLaunchPool(address _genesisPool) internal {
        (address nativeToken, address fundingToken, uint256 nativeDesired, uint256 fundingDesired, 
        address poolAddress, address gaugeAddress, bool stable) = IGenesisPool(_genesisPool).setLaunchStatus(PoolStatus.PARTIALLY_LAUNCHED);

        _addLiquidityAndDistribute(_genesisPool, nativeToken, fundingToken, nativeDesired, fundingDesired, poolAddress, gaugeAddress, stable);
    }

    function _addLiquidityAndDistribute(address _genesisPool, address nativeToken, address fundingToken, uint256 nativeDesired, uint256 fundingDesired, 
        address poolAddress, address gaugeAddress, bool stable) internal {

        pairFactory.setGenesisStatus(poolAddress, false);
        IGenesisPool(_genesisPool).approveTokens(router);

        (, , uint liquidity) = IRouter01(router).addLiquidity(nativeToken, fundingToken, stable, nativeDesired, fundingDesired, 0, 0, address(this), block.timestamp + 100);

        (address[] memory _accounts, uint256[] memory _amounts, address _tokenOwner) = IGenesisPool(_genesisPool).getLPTokensShares(liquidity);

        IERC20(poolAddress).approve(gaugeAddress, liquidity);
        IGauge(gaugeAddress).depositsForGenesis(_accounts, _amounts, _tokenOwner, block.timestamp + MATURITY_TIME, liquidity);
    }
    
    // before 3 hrs
    function checkBeforeEpochFlip() external nonReentrant{
        require(epochController == msg.sender, "invalid access");

        uint256 _proposedTokensCnt = proposedTokens.length;
        uint256 i;
        address _genesisPool;
        PoolStatus _poolStatus;
        for(i = 0; i < _proposedTokensCnt; i++){
            _genesisPool = genesisFactory.getGenesisPool(proposedTokens[i]);
            _poolStatus = IGenesisPool(_genesisPool).poolStatus();

            if(_poolStatus == PoolStatus.PRE_LISTING && IGenesisPool(_genesisPool).eligbleForDisqualify()){
                pairFactory.setGenesisStatus(IGenesisPool(_genesisPool).getLiquidityPoolInfo().pairAddress, false);
                IGenesisPool(_genesisPool).setPoolStatus(PoolStatus.NOT_QUALIFIED);
            }
            else if(_poolStatus == PoolStatus.PRE_LAUNCH){
                IGenesisPool(_genesisPool).setPoolStatus(PoolStatus.PRE_LAUNCH_DEPOSIT_DISABLED);
            }
        }
    }

    function getAllProposedTokens() external view returns (address[] memory) {
        return proposedTokens;
    }

    function setEpochController(address _epochController) external Governance {
        epochController = _epochController;
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