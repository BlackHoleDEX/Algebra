// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {BlackTimeLibrary} from "./libraries/BlackTimeLibrary.sol";

import "./interfaces/IGenesisPool.sol";
import "./interfaces/IGanesisPoolBase.sol";
import "./interfaces/ITokenHandler.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/IVoterV3.sol";
import "./interfaces/IBribe.sol";

contract GenesisPool is IGenesisPool, IGanesisPoolBase, ReentrancyGuardUpgradeable {

    using SafeERC20 for IERC20;

    address immutable internal factory;
    address immutable internal genesisManager;
    ITokenHandler immutable internal tokenHandler;
    IAuction immutable internal auction;
    IVoterV3 immutable internal voter;

    TokenAllocation public allocationInfo;
    TokenIncentiveInfo public incentiveInfo;
    GenesisInfo public genesisInfo;
    ProtocolInfo public protocolInfo;
    PoolStatus public poolStatus;
    LiquidityPool public liquidityPoolInfo;

    address[] public depositers;
    mapping(address => uint256) public userDeposits;

    event DepositedNativeToken(address native, address owner, address genesisPool, uint256 proposedNativeAmount, uint proposedFundingAmount);
    event AddedIncentives(address native, address[] incentivesToken, uint256[] incentivesAmount);
    event RejectedGenesisPool(address native);
    event ApprovedGenesisPool(address proposedToken);

    modifier onlyManager() {
        require(msg.sender == genesisManager);
        _;
    }

    constructor(address _factory, address _genesisManager, address _tokenHandler, address _voter, address _auction, address _tokenOwner, address _nativeToken, address _fundingToken){
        allocationInfo.tokenOwner = _tokenOwner;
        incentiveInfo.tokenOwner = _tokenOwner;
        protocolInfo.tokenAddress = _nativeToken;    
        genesisInfo.fundingToken = _fundingToken;

        factory = _factory;
        genesisManager = _genesisManager;
        tokenHandler = ITokenHandler(_tokenHandler);
        voter = IVoterV3(_voter);
        auction = IAuction(_auction);
    }


    function setGenesisPoolInfo(GenesisInfo calldata _genesisInfo, ProtocolInfo calldata _protocolInfo, TokenAllocation calldata _allocationInfo) external onlyManager(){
        genesisInfo = _genesisInfo;
        protocolInfo = _protocolInfo;

        genesisInfo.duration = BlackTimeLibrary.epochMultiples(genesisInfo.duration);
        genesisInfo.startTime = BlackTimeLibrary.epochNext(block.timestamp);

        allocationInfo.proposedNativeAmount = _allocationInfo.proposedNativeAmount;
        allocationInfo.proposedFundingAmount = _allocationInfo.proposedFundingAmount;
        allocationInfo.allocatedNativeAmount = 0;
        allocationInfo.allocatedFundingAmount = 0;
        allocationInfo.refundableNativeAmount = 0;

        poolStatus = PoolStatus.NATIVE_TOKEN_DEPOSITED;

        emit DepositedNativeToken(_protocolInfo.tokenAddress, allocationInfo.tokenOwner, address(this), _allocationInfo.proposedNativeAmount, _allocationInfo.proposedFundingAmount);
    }

    function addIncentives(address[] calldata _incentivesToken, uint256[] calldata _incentivesAmount) external {
        address _sender = msg.sender;
        require(_sender == allocationInfo.tokenOwner, "!= sender");
        require(poolStatus == PoolStatus.NATIVE_TOKEN_DEPOSITED || poolStatus == PoolStatus.PRE_LISTING, "!= status");
        require(_incentivesToken.length > 0, "0 len");
        require(_incentivesToken.length == _incentivesAmount.length, "!= len");
        uint256 _incentivesCnt = _incentivesToken.length;
        uint256 i = 0;

        for(i = 0; i < _incentivesCnt; i++){
            require(_incentivesToken[i] != address(0), "0x incen");
            require(_incentivesAmount[i] > 0, "0 incen");

            if(_incentivesToken[i] == protocolInfo.tokenAddress) continue;

            require(tokenHandler.isConnector(_incentivesToken[i]), "!=  connector");
        }

        for(i = 0; i < _incentivesCnt; i++){
            assert(IERC20(_incentivesToken[i]).transferFrom(_sender, address(this), _incentivesAmount[i]));
        }

        incentiveInfo.incentivesToken = _incentivesToken;
        incentiveInfo.incentivesAmount = _incentivesAmount;

        emit AddedIncentives(protocolInfo.tokenAddress, _incentivesToken, _incentivesAmount);
    }

    function rejectPool() external onlyManager {
        poolStatus = PoolStatus.NOT_QUALIFIED;
        allocationInfo.refundableNativeAmount = allocationInfo.proposedFundingAmount;
        emit RejectedGenesisPool(protocolInfo.tokenAddress);
    }

    function approvePool(address _pairAddress) external onlyManager {
        liquidityPoolInfo.pairAddress = _pairAddress;
        poolStatus = PoolStatus.PRE_LISTING;
        emit ApprovedGenesisPool(protocolInfo.tokenAddress);
    }

    function depositToken(address spender, uint256 amount) external onlyManager returns (bool) {
        require(amount > 0, "0 amt");
        require(poolStatus == PoolStatus.PRE_LISTING || poolStatus == PoolStatus.PRE_LAUNCH, "!= status");

        uint256 _amount = allocationInfo.proposedFundingAmount - allocationInfo.allocatedFundingAmount;
        _amount = _amount < amount ? _amount : amount;
        require(_amount > 0, "max amt");

        assert(IERC20(genesisInfo.fundingToken).transferFrom(spender, address(this), _amount));

        if(userDeposits[spender] == 0){
            depositers.push(spender);
        }

        userDeposits[spender] = userDeposits[spender] + _amount;

        allocationInfo.allocatedFundingAmount += _amount;
        allocationInfo.allocatedNativeAmount += _getProtcolTokenAmount(amount);

        return poolStatus == PoolStatus.PRE_LISTING && _eligbleForPreLaunchPool();
    }

    function eligbleForPreLaunchPool() external view returns (bool){
        return _eligbleForPreLaunchPool();
    }

    function _eligbleForPreLaunchPool() internal view returns (bool){
        uint _endTime = genesisInfo.startTime + genesisInfo.duration;
        uint256 targetFundingAmount = (allocationInfo.proposedFundingAmount * genesisInfo.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls

        return (BlackTimeLibrary.isLastEpoch(block.timestamp, _endTime) && allocationInfo.allocatedFundingAmount >= targetFundingAmount);
    }

    function eligbleForCompleteLaunch() external view returns (bool){
        uint256 targetFundingAmount = (allocationInfo.proposedFundingAmount * genesisInfo.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls
        return targetFundingAmount == allocationInfo.allocatedFundingAmount;
    }

    function transferIncentives(address gauge, address external_bribe, address internal_bribe) external onlyManager {
        liquidityPoolInfo.gaugeAddress = gauge;
        liquidityPoolInfo.external_bribe = external_bribe;
        liquidityPoolInfo.internal_bribe = internal_bribe;

        uint256 i = 0;
        uint256 _incentivesCnt = incentiveInfo.incentivesToken.length;
        for(i = 0; i < _incentivesCnt; i++){
            if(incentiveInfo.incentivesAmount[i] > 0)
            {
                IBribe(external_bribe).notifyRewardAmount(incentiveInfo.incentivesToken[i], incentiveInfo.incentivesAmount[i]);
            }
        }

        poolStatus = PoolStatus.PRE_LAUNCH;
    }

    function setLaunchStatus(PoolStatus status) external returns (address nativeToken, address fundingToken, 
        uint256 nativeDesired, uint256 fundingDesired, address poolAddress, address gaugeAddress, bool stable){
        
        if(status == PoolStatus.PARTIALLY_LAUNCHED){
            allocationInfo.refundableNativeAmount = allocationInfo.proposedNativeAmount - allocationInfo.allocatedNativeAmount;
        }
        else if(status == PoolStatus.LAUNCH){
            allocationInfo.refundableNativeAmount = 0;
        }

        nativeToken = protocolInfo.tokenAddress;
        fundingToken = genesisInfo.fundingToken;
        nativeDesired = allocationInfo.allocatedNativeAmount;
        fundingDesired = allocationInfo.allocatedFundingAmount;
        poolAddress = liquidityPoolInfo.pairAddress;
        gaugeAddress = liquidityPoolInfo.gaugeAddress;
        stable = protocolInfo.stable;
    }

    function approveTokens(address router) onlyManager external {
        IERC20(protocolInfo.tokenAddress).approve(router, allocationInfo.allocatedNativeAmount);
        IERC20(genesisInfo.fundingToken).approve(router, allocationInfo.allocatedFundingAmount);
    }

    function getLPTokensShares(uint256 liquidity) onlyManager external view returns (address[] memory _accounts, uint256[] memory _amounts, address _tokenOwner){
        
        uint256 _depositersCnt = depositers.length;
        uint256[] memory _deposits = new uint256[](_depositersCnt);
        uint256 i;
        for(i = 0; i < _depositersCnt; i++){
            _deposits[i] = userDeposits[depositers[i]];
        }

        _tokenOwner = allocationInfo.tokenOwner;
        (_accounts, _amounts) = auction.getLPTokensShares(depositers, _deposits, allocationInfo.tokenOwner, liquidity);
    }

    function getProtcolTokenAmount(uint256 depositAmount) external view returns (uint256){
        require(depositAmount > 0, "0 amt");
        return _getProtcolTokenAmount(depositAmount);
    }

    function _getProtcolTokenAmount(uint256 depositAmount) internal view returns (uint256){
        return auction.getProtcolTokenAmount(genesisInfo.startPrice, depositAmount, allocationInfo);
    }

    

    function allocation() external view returns (TokenAllocation memory){
        return allocationInfo;
    }

    function incentives() external view returns (IGanesisPoolBase.TokenIncentiveInfo memory){
        return incentiveInfo;
    }

    function genesis() external view returns (IGanesisPoolBase.GenesisInfo memory){
        return genesisInfo;
    }
    function protocol() external view returns (IGanesisPoolBase.ProtocolInfo memory){
        return protocolInfo;
    }

    function liquidityPool() external view returns (IGanesisPoolBase.LiquidityPool memory){
        return liquidityPoolInfo;
    }
}