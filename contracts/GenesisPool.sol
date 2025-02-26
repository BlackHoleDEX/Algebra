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
    IAuction internal auction;
    IVoterV3 immutable internal voter;

    TokenAllocation public allocationInfo;
    GenesisInfo public genesisInfo;
    ProtocolInfo public protocolInfo;
    PoolStatus public poolStatus;
    LiquidityPool public liquidityPoolInfo;

    address[] public incentiveTokens;
    mapping(address => uint256) public incentives;

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

    modifier onlyManagerOrProtocol() {
        require(msg.sender == genesisManager || msg.sender == allocationInfo.tokenOwner);
        _;
    }

    constructor(address _factory, address _genesisManager, address _tokenHandler, address _voter, address _auction, address _tokenOwner, address _nativeToken, address _fundingToken){
        allocationInfo.tokenOwner = _tokenOwner;
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
            if(incentives[_incentivesToken[i]] == 0){
                incentiveTokens.push(_incentivesToken[i]);
            }
            incentives[_incentivesToken[i]] += _incentivesAmount[i];
        }

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

        uint256 nativeAmount = _getNativeTokenAmount(amount);
        allocationInfo.allocatedFundingAmount += _amount;
        allocationInfo.allocatedNativeAmount += nativeAmount;

        IAuction(auction).purchased(nativeAmount);

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

    function eligbleForDisqualify() external view returns (bool){
        uint256 _endTime = genesisInfo.startTime + genesisInfo.duration;    
        uint256 targetFundingAmount = (allocationInfo.proposedFundingAmount * genesisInfo.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls

        return (BlackTimeLibrary.isLastEpoch(block.timestamp, _endTime) && targetFundingAmount < allocationInfo.allocatedFundingAmount);
    }

    function transferIncentives(address gauge, address external_bribe, address internal_bribe) external onlyManager {
        liquidityPoolInfo.gaugeAddress = gauge;
        liquidityPoolInfo.external_bribe = external_bribe;
        liquidityPoolInfo.internal_bribe = internal_bribe;

        uint256 i = 0;
        uint256 _amount = 0;
        uint256 _incentivesCnt = incentiveTokens.length;
        for(i = 0; i < _incentivesCnt; i++){
            _amount = incentives[incentiveTokens[i]];
            if(_amount > 0)
            {
                IBribe(external_bribe).notifyRewardAmount(incentiveTokens[i], _amount);
            }
        }

        poolStatus = PoolStatus.PRE_LAUNCH;
    }

    function setLaunchStatus(PoolStatus status) external onlyManager returns (address nativeToken, address fundingToken, 
        uint256 nativeDesired, uint256 fundingDesired, address poolAddress, address gaugeAddress, bool stable){
        
        _setPoolStatus(status);
        
        nativeToken = protocolInfo.tokenAddress;
        fundingToken = genesisInfo.fundingToken;
        nativeDesired = allocationInfo.allocatedNativeAmount;
        fundingDesired = allocationInfo.allocatedFundingAmount;
        poolAddress = liquidityPoolInfo.pairAddress;
        gaugeAddress = liquidityPoolInfo.gaugeAddress;
        stable = protocolInfo.stable;
    }

    function setPoolStatus(PoolStatus status) external onlyManager {
        _setPoolStatus(status);
    }

    function _setPoolStatus(PoolStatus status) internal {
        if(status == PoolStatus.PARTIALLY_LAUNCHED){
            allocationInfo.refundableNativeAmount = allocationInfo.proposedNativeAmount - allocationInfo.allocatedNativeAmount;
        }
        else if(status == PoolStatus.LAUNCH){
            allocationInfo.refundableNativeAmount = 0;
        }
        else if(status == PoolStatus.NOT_QUALIFIED){
            allocationInfo.refundableNativeAmount = allocationInfo.proposedNativeAmount;
        }

        poolStatus = status;
    }

    function approveTokens(address router) onlyManager external {
        IERC20(protocolInfo.tokenAddress).approve(router, allocationInfo.allocatedNativeAmount);
        IERC20(genesisInfo.fundingToken).approve(router, allocationInfo.allocatedFundingAmount);
    }

    function getLPTokensShares(uint256 liquidity) onlyManager external view returns (address[] memory _accounts, uint256[] memory _amounts, address _tokenOwner){
        
        require(liquidity > 0, "invalid liquidity");
        uint256 _depositersCnt = depositers.length;
        uint256 _totalDeposits = 0;
        uint256[] memory _deposits = new uint256[](_depositersCnt);
        uint256 i;
        for(i = 0; i < _depositersCnt; i++){
            _deposits[i] = userDeposits[depositers[i]];
            _totalDeposits += _deposits[i];
        }

        require(_totalDeposits > 0, "0 total deposits");

        _accounts = new address[](_depositersCnt + 1); 
        _amounts = new uint256[](_depositersCnt + 1); 

        uint256 _totalAdded = 0;
        uint256 _depositerLiquidity = liquidity / 2;

        for(i = 0; i < _depositersCnt; i++){
            _accounts[i+1] = depositers[i];
            _amounts[i+1] = (_depositerLiquidity * _deposits[i]) / _totalDeposits;
            _totalAdded += _amounts[i+1];
        }

        _tokenOwner = allocationInfo.tokenOwner;
        _accounts[0] = _tokenOwner;
        _amounts[0] = liquidity - _totalAdded;
    }

    function claimableUnallocatedAmount() public view returns(PoolStatus, address, uint256){
        if(poolStatus == PoolStatus.PARTIALLY_LAUNCHED){
            if(msg.sender == allocationInfo.tokenOwner){
                return (poolStatus, protocolInfo.tokenAddress, allocationInfo.refundableNativeAmount);
            } 
        }else if(poolStatus == PoolStatus.NOT_QUALIFIED){
            if(msg.sender == allocationInfo.tokenOwner){
                return (poolStatus, protocolInfo.tokenAddress, allocationInfo.refundableNativeAmount);
            }else{
                return (poolStatus, genesisInfo.fundingToken, userDeposits[msg.sender]);
            }
        }
        
        return (PoolStatus.DEFAULT, address(0), 0);
    }

    function claimUnallocatedAmount() external nonReentrant{
        require(poolStatus == PoolStatus.NOT_QUALIFIED || poolStatus == PoolStatus.PARTIALLY_LAUNCHED, "!= status");

        uint256 _amount;
        if(poolStatus == PoolStatus.PARTIALLY_LAUNCHED){
            if(msg.sender == allocationInfo.tokenOwner){
                _amount = allocationInfo.refundableNativeAmount;
                allocationInfo.refundableNativeAmount = 0;

                if(_amount > 0){
                    assert(IERC20(protocolInfo.tokenAddress).transfer(msg.sender, _amount));
                }
            } 
        }else if(poolStatus == PoolStatus.NOT_QUALIFIED){
            if(msg.sender == allocationInfo.tokenOwner){
                _amount = allocationInfo.refundableNativeAmount;
                allocationInfo.refundableNativeAmount = 0;

                if(_amount > 0){
                    assert(IERC20(protocolInfo.tokenAddress).transfer(msg.sender, _amount));
                }
            }else{
                _amount = userDeposits[msg.sender];
                userDeposits[msg.sender] = 0;

                if(_amount > 0){
                    assert(IERC20(genesisInfo.fundingToken).transfer(msg.sender, _amount));
                }
            }
        }
    }

    function claimableIncentives() public view returns(address[] memory tokens , uint256[] memory amounts){
        if(poolStatus == PoolStatus.NOT_QUALIFIED && msg.sender == allocationInfo.tokenOwner){
            tokens = incentiveTokens;
            uint256 incentivesCnt = incentiveTokens.length;
            amounts = new uint256[](incentivesCnt);
            uint256 i;
            for(i = 0; i < incentivesCnt; i++){
                amounts[i] = incentives[incentiveTokens[i]];
            }
        }
    }

    function claimIncentives() external nonReentrant{
        require(poolStatus == PoolStatus.NOT_QUALIFIED, "!= status");
        require(msg.sender == allocationInfo.tokenOwner, "!= onwer");

        uint256 _incentivesCnt = incentiveTokens.length;
        uint256 i;
        uint _amount;

        for(i = 0; i < _incentivesCnt; i++){
            _amount = incentives[incentiveTokens[i]];
            incentives[incentiveTokens[i]] = 0;

            assert(IERC20(incentiveTokens[i]).transfer(msg.sender, _amount));
        }
    }

    function getNativeTokenAmount(uint256 depositAmount) external view returns (uint256){
        require(depositAmount > 0, "0 amt");
        return _getNativeTokenAmount(depositAmount);
    }

    function _getNativeTokenAmount(uint256 depositAmount) internal view returns (uint256){
        return auction.getNativeTokenAmount(depositAmount);
    }

    function getAllocationInfo() external view returns (TokenAllocation memory){
        return allocationInfo;
    }

    function getIncentivesInfo() external view returns (IGanesisPoolBase.TokenIncentiveInfo memory incentiveInfo){
        incentiveInfo.incentivesToken = incentiveTokens;
        uint256 incentivesCnt = incentiveTokens.length;
        incentiveInfo.incentivesAmount = new uint256[](incentivesCnt);
        uint256 i;
        for(i = 0; i < incentivesCnt; i++){
            incentiveInfo.incentivesAmount[i] = incentives[incentiveTokens[i]];
        }
    }

    function getGenesisInfo() external view returns (IGanesisPoolBase.GenesisInfo memory){
        return genesisInfo;
    }
    function getProtocolInfo() external view returns (IGanesisPoolBase.ProtocolInfo memory){
        return protocolInfo;
    }

    function getLiquidityPoolInfo() external view returns (IGanesisPoolBase.LiquidityPool memory){
        return liquidityPoolInfo;
    }

    function setAuction(address _auction) external onlyManagerOrProtocol {
        require(_auction != address(0), "0x auc");
        auction = IAuction(_auction);
    }
}