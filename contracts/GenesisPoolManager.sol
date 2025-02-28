// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IGenesisPoolManager.sol";
import "./interfaces/IVoterV3.sol";
import "./interfaces/IGenesisPoolBase.sol";
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

contract GenesisPoolManager is IGenesisPoolBase, IGenesisPoolManager, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    uint256 public MIN_DURATION;
    uint256 public MIN_THRESHOLD;
    uint256 public MATURITY_TIME;

    address public epochController;
    address public permissionRegistory;
    address public router;
    IBaseV1Factory public pairFactory;
    IVoterV3 public voter;
    ITokenHandler public tokenHandler;

    IGenesisPoolFactory public genesisFactory;
    IAuctionFactory public auctionFactory;

    using SafeERC20 for IERC20;

    mapping(address => mapping(address => bool)) public whiteListedTokensToUser; 
    address[] public nativeTokens;
    
    event WhiteListedTokenToUser(address proposedToken, address tokenOwner);
    event DespositedToken(address genesisPool, address sender, uint256 amount);
    modifier Governance() {
        require(IPermissionsRegistry(permissionRegistory).hasRole("GOVERNANCE",msg.sender), 'GOVERNANCE');
        _;
    }

    function _checkGovernance() internal view returns (bool) {
        return IPermissionsRegistry(permissionRegistory).hasRole("GOVERNANCE",msg.sender);
    }

    constructor() {}

    function initialize(address _epochController, address _router, address _permissionRegistory, address _voter, address _pairFactory, address _genesisFactory, address _auctionFactory, address _tokenHandler) initializer  public {
        __Ownable_init();
        __ReentrancyGuard_init();

        epochController = _epochController;
        router = _router;
        permissionRegistory = _permissionRegistory;
        voter = IVoterV3(_voter);
        pairFactory = IBaseV1Factory(_pairFactory);
        genesisFactory = IGenesisPoolFactory(_genesisFactory);
        auctionFactory = IAuctionFactory(_auctionFactory);
        tokenHandler = ITokenHandler(_tokenHandler);

        MIN_DURATION = 7 days; 
        MIN_THRESHOLD = 50 * 10 ** 2; 
        MATURITY_TIME = 90 days;
    }

    function whiteListUserAndToken(address tokenOwner, address proposedToken) external Governance nonReentrant{
        whiteListedTokensToUser[proposedToken][tokenOwner] = true;
        emit WhiteListedTokenToUser(proposedToken, tokenOwner);
    }

    function depositNativeToken(address nativeToken, uint auctionIndex, GenesisInfo calldata genesisPoolInfo, TokenAllocation calldata allocationInfo) external nonReentrant returns(address genesisPool) {
        address _sender = msg.sender;
        require(whiteListedTokensToUser[nativeToken][_sender] || _checkGovernance(), "!listed");
        require(allocationInfo.proposedNativeAmount > 0, "0 native");
        require(allocationInfo.proposedFundingAmount > 0, "0 funding");
        require(genesisFactory.getGenesisPool(nativeToken) == address(0), "exists");

        address _fundingToken = genesisPoolInfo.fundingToken;
        require(tokenHandler.isConnector(_fundingToken), "conn !=");
        bool _stable = genesisPoolInfo.stable;
        require(pairFactory.getPair(nativeToken, _fundingToken, _stable) == address(0), "exist pair");

        require(genesisPoolInfo.duration >= MIN_DURATION && genesisPoolInfo.threshold >= MIN_THRESHOLD && genesisPoolInfo.startPrice > 0, "genesis info");
        require(genesisPoolInfo.supplyPercent > 0 && genesisPoolInfo.supplyPercent <= 10000, "supplyPercent"); 
        
        require(genesisPoolInfo.nativeToken == nativeToken, "!= nativeToken");
        
        genesisPool = genesisFactory.createGenesisPool(_sender, nativeToken, _fundingToken);
        require(genesisPool != address(0), "0x");

        assert(IERC20(nativeToken).transferFrom(_sender, genesisPool, allocationInfo.proposedNativeAmount));

        address auction = auctionFactory.auctions(auctionIndex);
        auction = auction == address(0) ? auctionFactory.auctions(0) : auction;
        IGenesisPool(genesisPool).setAuction(auction);

        nativeTokens.push(nativeToken); 
        IGenesisPool(genesisPool).setGenesisPoolInfo(genesisPoolInfo, allocationInfo);
    }

    function rejectGenesisPool(address nativeToken) external Governance nonReentrant {
        require(nativeToken != address(0), "0x native");
        address genesisPool = genesisFactory.getGenesisPool(nativeToken);
        require(genesisPool != address(0), '0x pool');

        IGenesisPool(genesisPool).rejectPool();
        genesisFactory.removeGenesisPool(nativeToken);
        
    }

    function approveGenesisPool(address nativeToken) external Governance nonReentrant {
        require(nativeToken != address(0), "0x native");
        address genesisPool = genesisFactory.getGenesisPool(nativeToken);
        require(genesisPool != address(0), '0x pool');

        tokenHandler.whitelistToken(nativeToken);

        GenesisInfo memory genesisInfo =  IGenesisPool(genesisPool).getGenesisInfo();
        address pairAddress = pairFactory.createPair(nativeToken, genesisInfo.fundingToken, genesisInfo.stable);
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

        uint256 _proposedTokensCnt = nativeTokens.length;
        uint256 i;
        address _genesisPool;
        PoolStatus _poolStatus;
        for(i = 0; i < _proposedTokensCnt; i++){
            _genesisPool = genesisFactory.getGenesisPool(nativeTokens[i]);
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
        pairFactory.setGenesisStatus(IGenesisPool(_genesisPool).getLiquidityPoolInfo().pairAddress, false);
        IGenesisPool(_genesisPool).launch(router, MATURITY_TIME);
    }
    
    // before 3 hrs
    function checkBeforeEpochFlip() external nonReentrant{
        require(epochController == msg.sender, "invalid access");

        uint256 _proposedTokensCnt = nativeTokens.length;
        uint256 i;
        address _genesisPool;
        PoolStatus _poolStatus;
        for(i = 0; i < _proposedTokensCnt; i++){
            _genesisPool = genesisFactory.getGenesisPool(nativeTokens[i]);
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

    function setAuction(address _genesisPool, address _auction) external Governance {
        require(_genesisPool != address(0), "0x pool");
        IGenesisPool(_genesisPool).setAuction(_auction);
    }

    function getAllNaitveTokens() external view returns (address[] memory) {
        return nativeTokens;
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