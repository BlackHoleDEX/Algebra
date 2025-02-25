// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IGenesisPool.sol";
import "./interfaces/IGanesisPoolBase.sol";

contract GenesisPool is IGenesisPool, IGanesisPoolBase, ReentrancyGuardUpgradeable {

    using SafeERC20 for IERC20;

    address immutable internal factory;
    address immutable internal genesisManager;

    TokenAllocation public allocationInfo;
    TokenIncentiveInfo public incentiveInfo;
    GenesisInfo public genesisInfo;
    ProtocolInfo public protocolInfo;
    PoolStatus public poolStatus;
    LiquidityPool public liquidityPoolInfo;

    address[] public depositers;
    mapping(address => uint256) public userDeposits;

    event DepositedNativeToken(address proposedToken, address genesisPool, uint256 proposedNativeAmount, uint proposedFundingAmount);
    event AddedIncentives(address proposedToken, address[] incentivesToken, uint256[] incentivesAmount);

    modifier onlyManager() {
        require(msg.sender == genesisManager);
        _;
    }

    constructor(address _factory, address _genesisManager, address _tokenOwner, address _nativeToken, address _fundingToken){
        allocationInfo.tokenOwner = _tokenOwner;
        incentiveInfo.tokenOwner = _tokenOwner;
        protocolInfo.tokenAddress = _nativeToken;    
        genesisInfo.fundingToken = _fundingToken;

        factory = _factory;
        genesisManager = _genesisManager;
    }


    function setGenesisPoolInfo(GenesisInfo calldata _genesisInfo, ProtocolInfo calldata _protocolInfo, uint256 _proposedNativeAmount, uint _proposedFundingAmount) external onlyManager(){
        genesisInfo = _genesisInfo;
        protocolInfo = _protocolInfo;

        allocationInfo.proposedNativeAmount = _proposedNativeAmount;
        allocationInfo.proposedFundingAmount = _proposedFundingAmount;
        allocationInfo.allocatedNativeAmount = 0;
        allocationInfo.allocatedFundingAmount = 0;
        allocationInfo.refundableNativeAmount = 0;

        poolStatus = PoolStatus.NATIVE_TOKEN_DEPOSITED;

        emit DepositedNativeToken(allocationInfo.tokenOwner, address(this), _proposedNativeAmount, _proposedFundingAmount);
    }

    function addIncentives(address _sender, address _nativeToken, address[] calldata _incentivesToken, uint256[] calldata _incentivesAmount) external onlyManager{
        require(_nativeToken == protocolInfo.tokenAddress, "!= native");
        require(_sender == allocationInfo.tokenOwner, "!= sender");
        require(poolStatus == PoolStatus.NATIVE_TOKEN_DEPOSITED || poolStatus == PoolStatus.APPLIED || poolStatus == PoolStatus.PRE_LISTING, "!= status");

        uint256 _incentivesCnt = _incentivesToken.length;
        uint256 i = 0;
        for(i = 0; i < _incentivesCnt; i++){
            assert(IERC20(_incentivesToken[i]).transferFrom(_sender, address(this), _incentivesAmount[i]));
        }

        incentiveInfo.incentivesToken = _incentivesToken;
        incentiveInfo.incentivesAmount = _incentivesAmount;

        emit AddedIncentives(_nativeToken, _incentivesToken, _incentivesAmount);
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