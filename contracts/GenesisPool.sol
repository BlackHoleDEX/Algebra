// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {BlackTimeLibrary} from "./libraries/BlackTimeLibrary.sol";

import "./interfaces/IGenesisPool.sol";
import "./interfaces/IGenesisPoolBase.sol";
import "./interfaces/ITokenHandler.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IBribe.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IGauge.sol";

contract GenesisPool is IGenesisPool, IGenesisPoolBase {

    using SafeERC20 for IERC20;

    address immutable internal factory;
    address immutable internal genesisManager;
    ITokenHandler immutable internal tokenHandler;
    IAuction internal auction;
    IVoter immutable internal voter;

    TokenAllocation public allocationInfo;
    GenesisInfo public genesisInfo;
    PoolStatus public poolStatus;
    LiquidityPool public liquidityPoolInfo;

    address[] public incentiveTokens;
    mapping(address => uint256) public incentives;

    address[] public depositers;
    mapping(address => uint256) public userDeposits;

    uint256 internal totalDeposits;
    uint256 liquidity;
    uint256 tokenOwnerUnstaked;

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

    modifier onlyGauge() {
        require(msg.sender == liquidityPoolInfo.gaugeAddress);
        _;
    }

    constructor(address _factory, address _genesisManager, address _tokenHandler, address _voter, address _tokenOwner, address _nativeToken, address _fundingToken){
        allocationInfo.tokenOwner = _tokenOwner;
        genesisInfo.nativeToken = _nativeToken;    
        genesisInfo.fundingToken = _fundingToken;

        factory = _factory;
        genesisManager = _genesisManager;
        tokenHandler = ITokenHandler(_tokenHandler);
        voter = IVoter(_voter);

        totalDeposits = 0;
        liquidity = 0;
        tokenOwnerUnstaked = 0;
    }


    function setGenesisPoolInfo(GenesisInfo calldata _genesisInfo, TokenAllocation calldata _allocationInfo, address _auction) external onlyManager(){
        genesisInfo = _genesisInfo;

        genesisInfo.duration = BlackTimeLibrary.epochMultiples(genesisInfo.duration);
        genesisInfo.startTime = BlackTimeLibrary.epochStart(block.timestamp);
        
        allocationInfo.proposedNativeAmount = _allocationInfo.proposedNativeAmount;
        allocationInfo.proposedFundingAmount = _allocationInfo.proposedFundingAmount;
        allocationInfo.allocatedNativeAmount = 0;
        allocationInfo.allocatedFundingAmount = 0;
        allocationInfo.refundableNativeAmount = 0;

        auction = IAuction(_auction);
        poolStatus = PoolStatus.NATIVE_TOKEN_DEPOSITED;

        emit DepositedNativeToken(_genesisInfo.nativeToken, allocationInfo.tokenOwner, address(this), _allocationInfo.proposedNativeAmount, _allocationInfo.proposedFundingAmount);
    }

    function addIncentives(address[] calldata _incentivesToken, uint256[] calldata _incentivesAmount) external {
        address _sender = msg.sender;
        require(_sender == allocationInfo.tokenOwner, "!= sender");
        require(poolStatus == PoolStatus.NATIVE_TOKEN_DEPOSITED || poolStatus == PoolStatus.PRE_LISTING, "!= status");
        require(_incentivesToken.length > 0, "0 len");
        require(_incentivesToken.length == _incentivesAmount.length, "!= len");
        uint256 _incentivesCnt = _incentivesToken.length;
        uint256 i = 0;

        address _token;
        uint256 _amount;
        for(i = 0; i < _incentivesCnt; i++){
            _token = _incentivesToken[i];
            _amount = _incentivesAmount[i];
            if(_token != address(0) && _amount > 0 && (_token == genesisInfo.nativeToken || tokenHandler.isConnector(_token))){
                assert(IERC20(_token).transferFrom(_sender, address(this), _amount));
                if(incentives[_token] == 0){
                    incentiveTokens.push(_token);
                }
                incentives[_token] += _amount;
            }
        }

        emit AddedIncentives(genesisInfo.nativeToken, _incentivesToken, _incentivesAmount);
    }

    function rejectPool() external onlyManager {
        require(poolStatus == PoolStatus.NATIVE_TOKEN_DEPOSITED, "!= status");
        poolStatus = PoolStatus.NOT_QUALIFIED;
        allocationInfo.refundableNativeAmount = allocationInfo.proposedNativeAmount;
        emit RejectedGenesisPool(genesisInfo.nativeToken);
    }

    function approvePool(address _pairAddress) external onlyManager {
        require(poolStatus == PoolStatus.NATIVE_TOKEN_DEPOSITED, "!= status");
        liquidityPoolInfo.pairAddress = _pairAddress;
        poolStatus = PoolStatus.PRE_LISTING;
        emit ApprovedGenesisPool(genesisInfo.nativeToken);
    }

    function depositToken(address spender, uint256 amount) external onlyManager returns (bool) {
        require(poolStatus == PoolStatus.PRE_LISTING || poolStatus == PoolStatus.PRE_LAUNCH, "!= status");
        require(block.timestamp >= genesisInfo.startTime, "! started");

        uint256 _amount = allocationInfo.proposedFundingAmount - allocationInfo.allocatedFundingAmount;
        _amount = _amount < amount ? _amount : amount;
        require(_amount > 0, "max amt");

        assert(IERC20(genesisInfo.fundingToken).transferFrom(spender, address(this), _amount));

        if(userDeposits[spender] == 0){
            depositers.push(spender);
        }

        userDeposits[spender] = userDeposits[spender] + _amount;
        totalDeposits += _amount;

        uint256 nativeAmount = _getNativeTokenAmount(totalDeposits);
        allocationInfo.allocatedFundingAmount += _amount;
        allocationInfo.allocatedNativeAmount = nativeAmount;

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

    function _eligbleForCompleteLaunch() internal view returns (bool){
        uint256 targetFundingAmount = (allocationInfo.proposedFundingAmount * genesisInfo.threshold) / 10000; // threshold is 100 * of original to support 2 deciamls
        return allocationInfo.allocatedFundingAmount >= targetFundingAmount;
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
                IERC20(incentiveTokens[i]).approve(external_bribe, _amount);
                IBribe(external_bribe).notifyRewardAmount(incentiveTokens[i], _amount);
            }
        }

        poolStatus = PoolStatus.PRE_LAUNCH;
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

    function _approveTokens(address router) internal {
        IERC20(genesisInfo.nativeToken).approve(router, allocationInfo.allocatedNativeAmount);
        IERC20(genesisInfo.fundingToken).approve(router, allocationInfo.allocatedFundingAmount);
    }

    function _addLiquidityAndDistribute(address _router, uint256 nativeDesired, uint256 fundingDesired, uint256 maturityTime) internal {
        (, , uint _liquidity) = IRouter(_router).addLiquidity(genesisInfo.nativeToken, genesisInfo.fundingToken, genesisInfo.stable, nativeDesired, fundingDesired, 0, 0, address(this), block.timestamp + 100);
        liquidity = _liquidity;
        IERC20(liquidityPoolInfo.pairAddress).approve(liquidityPoolInfo.gaugeAddress, liquidity);
        IGauge(liquidityPoolInfo.gaugeAddress).depositsForGenesis(allocationInfo.tokenOwner, block.timestamp + maturityTime, liquidity);
    }

    function _launchCompletely(address router, uint256 maturityTime) internal {
        _approveTokens(router);
        _addLiquidityAndDistribute(router,  allocationInfo.allocatedNativeAmount,  allocationInfo.allocatedFundingAmount, maturityTime);
        _setPoolStatus(PoolStatus.LAUNCH);
    }

    function _launchPartially(address router, uint256 maturityTime) internal {
        _approveTokens(router);
        _addLiquidityAndDistribute(router,  allocationInfo.allocatedNativeAmount,  allocationInfo.allocatedFundingAmount, maturityTime);
        _setPoolStatus(PoolStatus.PARTIALLY_LAUNCHED);
    }

    function launch(address router, uint256 maturityTime) external onlyManager {
        if(_eligbleForCompleteLaunch()){
            _launchCompletely(router, maturityTime);
        }else{
            _launchPartially(router, maturityTime);
        }
    }

    function claimableUnallocatedAmount() public view returns(PoolStatus, address[] memory addresses, uint256[] memory amounts){
        uint claimableCnt = 1;
        if(poolStatus == PoolStatus.NOT_QUALIFIED && msg.sender == allocationInfo.tokenOwner){
            claimableCnt++;
        }

        addresses = new address[](claimableCnt);
        amounts = new uint256[](claimableCnt);

        if(poolStatus == PoolStatus.PARTIALLY_LAUNCHED){
            if(msg.sender == allocationInfo.tokenOwner){
                addresses[0] = genesisInfo.nativeToken;
                amounts[0] = allocationInfo.refundableNativeAmount;
            } 
        }else if(poolStatus == PoolStatus.NOT_QUALIFIED){
            addresses[0] = genesisInfo.fundingToken;
            amounts[0] = userDeposits[msg.sender];
            if(msg.sender == allocationInfo.tokenOwner){
                addresses[1] = genesisInfo.nativeToken;
                amounts[1] = allocationInfo.refundableNativeAmount;
            }
        }
        
        return (PoolStatus.DEFAULT, addresses, amounts);
    }

    function claimUnallocatedAmount() external {
        require(poolStatus == PoolStatus.NOT_QUALIFIED || poolStatus == PoolStatus.PARTIALLY_LAUNCHED, "!= status");

        uint256 _amount;
        if(poolStatus == PoolStatus.PARTIALLY_LAUNCHED){
            if(msg.sender == allocationInfo.tokenOwner){
                _amount = allocationInfo.refundableNativeAmount;
                allocationInfo.refundableNativeAmount = 0;

                if(_amount > 0){
                    assert(IERC20(genesisInfo.nativeToken).transfer(msg.sender, _amount));
                }
            } 
        }else if(poolStatus == PoolStatus.NOT_QUALIFIED){
            if(msg.sender == allocationInfo.tokenOwner){
                _amount = allocationInfo.refundableNativeAmount;
                allocationInfo.refundableNativeAmount = 0;

                if(_amount > 0){
                    assert(IERC20(genesisInfo.nativeToken).transfer(msg.sender, _amount));
                }
            }

            _amount = userDeposits[msg.sender];
            userDeposits[msg.sender] = 0;

            if(_amount > 0){
                assert(IERC20(genesisInfo.fundingToken).transfer(msg.sender, _amount));
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

    function claimIncentives() external {
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

    function balanceOf(address account) external view returns (uint256) {
        uint256 _depositerLiquidity = liquidity / 2;
        uint256 balance = (_depositerLiquidity * userDeposits[account]) / totalDeposits;
        if(account == allocationInfo.tokenOwner) balance += (liquidity - _depositerLiquidity - tokenOwnerUnstaked);
        return balance;
    }

    function deductAmount(address account, uint256 gaugeTokenAmount) external onlyGauge {
        uint256 _depositerLiquidity = liquidity / 2;
        uint256 userAmount = (totalDeposits * gaugeTokenAmount) / _depositerLiquidity; 

        if(account == allocationInfo.tokenOwner) {
            uint256 pendingOwnerStaked = liquidity - _depositerLiquidity - tokenOwnerUnstaked;

            if(gaugeTokenAmount < pendingOwnerStaked){
                tokenOwnerUnstaked += gaugeTokenAmount;
                userAmount = 0;
            }else{
                tokenOwnerUnstaked = liquidity - _depositerLiquidity;
                userAmount -= (totalDeposits * pendingOwnerStaked) / _depositerLiquidity;
            }
        }
        userDeposits[account] -= userAmount;
    }

    function deductAllAmount(address account) external onlyGauge {
        uint256 _depositerLiquidity = liquidity / 2;
        if(account == allocationInfo.tokenOwner) tokenOwnerUnstaked = liquidity - _depositerLiquidity;
        userDeposits[account] = 0;
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

    function getIncentivesInfo() external view returns (IGenesisPoolBase.TokenIncentiveInfo memory incentiveInfo){
        uint256 incentivesCnt = incentiveTokens.length;
        incentiveInfo.incentivesToken = new address[](incentivesCnt);
        incentiveInfo.incentivesAmount = new uint256[](incentivesCnt);
        uint256 i;
        for(i = 0; i < incentivesCnt; i++){
            incentiveInfo.incentivesToken[i] = incentiveTokens[i];
            incentiveInfo.incentivesAmount[i] = incentives[incentiveTokens[i]];
        }
    }

    function getGenesisInfo() external view returns (IGenesisPoolBase.GenesisInfo memory){
        return genesisInfo;
    }

    function getLiquidityPoolInfo() external view returns (IGenesisPoolBase.LiquidityPool memory){
        return liquidityPoolInfo;
    }

    function setAuction(address _auction) external onlyManagerOrProtocol {
        require(_auction != address(0), "0x auc");
        require(poolStatus == PoolStatus.NATIVE_TOKEN_DEPOSITED, "!= status");
        auction = IAuction(_auction);
    }
}