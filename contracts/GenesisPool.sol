// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {BlackTimeLibrary} from "./libraries/BlackTimeLibrary.sol";

import "./interfaces/IGenesisPool.sol";
import "./interfaces/IGanesisPoolBase.sol";
import "./interfaces/ITokenHandler.sol";

contract GenesisPool is IGenesisPool, IGanesisPoolBase, ReentrancyGuardUpgradeable {

    using SafeERC20 for IERC20;

    address immutable internal factory;
    address immutable internal genesisManager;
    ITokenHandler immutable internal tokenHandler;

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

    constructor(address _factory, address _genesisManager, address _tokenHandler, address _tokenOwner, address _nativeToken, address _fundingToken){
        allocationInfo.tokenOwner = _tokenOwner;
        incentiveInfo.tokenOwner = _tokenOwner;
        protocolInfo.tokenAddress = _nativeToken;    
        genesisInfo.fundingToken = _fundingToken;

        factory = _factory;
        genesisManager = _genesisManager;
        tokenHandler = ITokenHandler(_tokenHandler);
    }


    function setGenesisPoolInfo(GenesisInfo calldata _genesisInfo, ProtocolInfo calldata _protocolInfo, uint256 _proposedNativeAmount, uint _proposedFundingAmount) external onlyManager(){
        genesisInfo = _genesisInfo;
        protocolInfo = _protocolInfo;

        genesisInfo.duration = BlackTimeLibrary.epochMultiples(genesisInfo.duration);
        genesisInfo.startTime = BlackTimeLibrary.epochNext(block.timestamp);

        allocationInfo.proposedNativeAmount = _proposedNativeAmount;
        allocationInfo.proposedFundingAmount = _proposedFundingAmount;
        allocationInfo.allocatedNativeAmount = 0;
        allocationInfo.allocatedFundingAmount = 0;
        allocationInfo.refundableNativeAmount = 0;

        poolStatus = PoolStatus.NATIVE_TOKEN_DEPOSITED;

        emit DepositedNativeToken(_protocolInfo.tokenAddress, allocationInfo.tokenOwner, address(this), _proposedNativeAmount, _proposedFundingAmount);
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