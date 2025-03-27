// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IGenesisPoolBase.sol"; 
import '../interfaces/IGenesisPoolManager.sol';
import '../interfaces/IGenesisPoolFactory.sol';
import '../interfaces/IGenesisPool.sol';
import '../interfaces/IERC20.sol';
import {BlackTimeLibrary} from "../libraries/BlackTimeLibrary.sol";

contract GenesisPoolAPI is IGenesisPoolBase, Initializable {

    struct GenesisData {
        address genesisPool;
        address nativeToken;

        uint nativeTokensDecimal;
        uint fundingTokensDecimal;

        uint256 userDeposit;
        uint256 estimatedNativeAmount;

        TokenAllocation tokenAllocation;
        TokenIncentiveInfo incentiveInfo;
        GenesisInfo genesisInfo;
        LiquidityPool liquidityPool;
        PoolStatus poolStatus;
    }

    address public owner;
    IGenesisPoolManager public genesisManager;
    IGenesisPoolFactory public genesisPoolFactory;

    uint256 public constant MAX_POOLS = 1000;

    constructor() {}

    function initialize(address _genesisManager, address _genesisPoolFactory) initializer public {
  
        owner = msg.sender;

        genesisManager = IGenesisPoolManager(_genesisManager);
        genesisPoolFactory = IGenesisPoolFactory(_genesisPoolFactory);
    }

    function getGenesisPoolFromNative(address _user, address nativeToken) external view returns (GenesisData memory genesisData){
        address genesisPool = genesisPoolFactory.getGenesisPool(nativeToken);
        if(genesisPool == address(0)) return genesisData;

        return _getGenesisPool(_user, genesisPool);
    }

    function getGenesisPool(address _user, address genesisPool) external view returns (GenesisData memory genesisData){
        return _getGenesisPool(_user, genesisPool);
    }

    function _getGenesisPool(address _user, address genesisPool) internal view returns (GenesisData memory genesisData){
        GenesisInfo memory genesisInfo = IGenesisPool(genesisPool).getGenesisInfo();
        address fundingToken = genesisInfo.fundingToken;
        address nativeToken = genesisInfo.nativeToken;
        uint256 userDeposit;

        genesisData.nativeToken = nativeToken;
        genesisData.genesisPool = genesisPool;

        genesisData.nativeTokensDecimal = IERC20(nativeToken).decimals();
        genesisData.fundingTokensDecimal = IERC20(fundingToken).decimals();

        userDeposit = _user != address(0) ? IGenesisPool(genesisPool).userDeposits(_user) : 0;
        genesisData.userDeposit = userDeposit;
        genesisData.estimatedNativeAmount = userDeposit > 0 ? IGenesisPool(genesisPool).getNativeTokenAmount(userDeposit) : 0;

        genesisData.tokenAllocation = IGenesisPool(genesisPool).getAllocationInfo();
        genesisData.incentiveInfo = IGenesisPool(genesisPool).getIncentivesInfo();
        genesisData.genesisInfo = genesisInfo;
        genesisData.liquidityPool = IGenesisPool(genesisPool).getLiquidityPoolInfo();
        genesisData.poolStatus = IGenesisPool(genesisPool).poolStatus();
    }

    function getAllGenesisPools(address _user, uint _amounts, uint _offset) external view returns(uint totalPools, bool hasNext, GenesisData[] memory genesisPools){
        require(_amounts <= MAX_POOLS, 'too many pools');

        address[] memory proposedTokens = genesisManager.getLiveNaitveTokens();
        
        // Precompute pool index mapping to quickly skip to the correct offset
        uint[] memory poolIndexes = new uint[](proposedTokens.length);
        totalPools = 0;
        for(uint i = 0; i < proposedTokens.length; i++) {
            poolIndexes[i] = totalPools;
            totalPools += genesisPoolFactory.getGenesisPools(proposedTokens[i]).length;
        }

        // Find the correct token and local offset
        uint tokenIndex = 0;
        uint localOffset = _offset;
        while(tokenIndex < proposedTokens.length - 1 && localOffset >= poolIndexes[tokenIndex + 1]) {
            tokenIndex++;
            localOffset -= poolIndexes[tokenIndex];
        }

        genesisPools = new GenesisData[](_amounts);
        uint currentIndex = 0;
        hasNext = true;

        // Start from the identified token and local offset
        for(uint i = tokenIndex; i < proposedTokens.length; i++) {
            address nativeToken = proposedTokens[i];
            address[] memory genesisPoolsPerToken = genesisPoolFactory.getGenesisPools(nativeToken);

            for(uint j = (i == tokenIndex ? localOffset : 0); j < genesisPoolsPerToken.length; j++) {
                if (currentIndex >= _amounts) {
                    return (totalPools, true, genesisPools);
                }

                address genesisPool = genesisPoolsPerToken[j];
                GenesisInfo memory genesisInfo = IGenesisPool(genesisPool).getGenesisInfo();

                genesisPools[currentIndex].genesisPool = genesisPool;
                genesisPools[currentIndex].nativeToken = nativeToken;

                genesisPools[currentIndex].nativeTokensDecimal = IERC20(nativeToken).decimals();
                genesisPools[currentIndex].fundingTokensDecimal = IERC20(genesisInfo.fundingToken).decimals();

                uint256 userDeposit = _user != address(0) ? IGenesisPool(genesisPool).userDeposits(_user) : 0;
                genesisPools[currentIndex].userDeposit = userDeposit;
                genesisPools[currentIndex].estimatedNativeAmount = userDeposit > 0 ? IGenesisPool(genesisPool).getNativeTokenAmount(userDeposit) : 0;

                genesisPools[currentIndex].tokenAllocation = IGenesisPool(genesisPool).getAllocationInfo();
                genesisPools[currentIndex].incentiveInfo = IGenesisPool(genesisPool).getIncentivesInfo();
                genesisPools[currentIndex].genesisInfo = genesisInfo;
                genesisPools[currentIndex].liquidityPool = IGenesisPool(genesisPool).getLiquidityPoolInfo();
                genesisPools[currentIndex].poolStatus = IGenesisPool(genesisPool).poolStatus();

                currentIndex++;
            }
        }

        hasNext = (poolIndexes[proposedTokens.length - 1] + genesisPoolFactory.getGenesisPools(proposedTokens[proposedTokens.length - 1]).length) > (_offset + currentIndex);
        return (totalPools, hasNext, genesisPools);
    }
   
    function getAllUserRelatedGenesisPools(address _user) external view returns(uint totalTokens, GenesisData[] memory genesisPools){
        address[] memory proposedTokens = genesisManager.getAllNaitveTokens();
        totalTokens = proposedTokens.length;

        uint i = 0;
        uint count = 0;
        address genesisPool;
        address nativeToken;
        TokenAllocation memory tokenAllocation;
        TokenIncentiveInfo memory incentiveInfo;
        GenesisInfo memory genesisInfo;
        PoolStatus poolStatus;
        uint256 userDeposit;

        for(i; i < totalTokens; i++){
            nativeToken = proposedTokens[i];

            address[] memory genesisPoolsPerToken = genesisPoolFactory.getGenesisPools(nativeToken);
            for(uint j =0; j < genesisPoolsPerToken.length; j++){
                genesisPool = genesisPoolsPerToken[j];
                poolStatus = IGenesisPool(genesisPool).poolStatus();

                if(poolStatus == PoolStatus.DEFAULT || poolStatus == PoolStatus.LAUNCH)
                    continue;
                
                userDeposit = _user != address(0) ? IGenesisPool(genesisPool).userDeposits(_user) : 0;
                tokenAllocation = IGenesisPool(genesisPool).getAllocationInfo();
                incentiveInfo = IGenesisPool(genesisPool).getIncentivesInfo();
                genesisInfo = IGenesisPool(genesisPool).getGenesisInfo();

                if(_hasClaimbaleForOwner(_user, userDeposit, poolStatus, genesisInfo.tokenOwner, tokenAllocation, incentiveInfo)){
                    count++;
                }
            }
        }

        genesisPools = new GenesisData[](count);
        uint index = 0;
        i = 0;

        for(i; i < totalTokens; i++){
            nativeToken = proposedTokens[i];

            address[] memory genesisPoolsPerToken = genesisPoolFactory.getGenesisPools(nativeToken);
            for(uint j =0; j < genesisPoolsPerToken.length; j++){
                genesisPool = genesisPoolsPerToken[j];
                poolStatus = IGenesisPool(genesisPool).poolStatus();

                if(poolStatus == PoolStatus.DEFAULT || poolStatus == PoolStatus.LAUNCH)
                    continue;
                
                userDeposit = _user != address(0) ? IGenesisPool(genesisPool).userDeposits(_user) : 0;
                tokenAllocation = IGenesisPool(genesisPool).getAllocationInfo();
                incentiveInfo = IGenesisPool(genesisPool).getIncentivesInfo();
                genesisInfo = IGenesisPool(genesisPool).getGenesisInfo();

                if(_hasClaimbaleForOwner(_user, userDeposit, poolStatus, genesisInfo.tokenOwner, tokenAllocation, incentiveInfo)){
                
                    genesisPools[index].genesisPool = genesisPool;
                    genesisPools[index].nativeToken = nativeToken;

                    genesisPools[index].nativeTokensDecimal = IERC20(nativeToken).decimals();
                    genesisPools[index].fundingTokensDecimal = IERC20(genesisInfo.fundingToken).decimals();

                    genesisPools[index].userDeposit = userDeposit;
                    genesisPools[index].estimatedNativeAmount = userDeposit > 0 ? IGenesisPool(genesisPool).getNativeTokenAmount(userDeposit) : 0;

                    genesisPools[index].tokenAllocation = tokenAllocation;
                    genesisPools[index].incentiveInfo = IGenesisPool(genesisPool).getIncentivesInfo();
                    genesisPools[index].genesisInfo = genesisInfo;
                    genesisPools[index].liquidityPool = IGenesisPool(genesisPool).getLiquidityPoolInfo();
                    genesisPools[index].poolStatus = IGenesisPool(genesisPool).poolStatus();
                    index++;
                }
            }
        }

        totalTokens = count;
    }

    function _hasClaimbaleForOwner(address _user, uint256 userDeposit, PoolStatus poolStatus, address tokenOwner, TokenAllocation memory tokenAllocation, TokenIncentiveInfo memory incentiveInfo) internal pure returns (bool) {
        if(_user == tokenOwner){
            if(poolStatus == PoolStatus.NOT_QUALIFIED){
                return (tokenAllocation.refundableNativeAmount > 0 || incentiveInfo.incentivesToken.length > 0);
            }
            else if(poolStatus == PoolStatus.NATIVE_TOKEN_DEPOSITED){
                return (tokenAllocation.proposedNativeAmount > 0 || incentiveInfo.incentivesToken.length > 0);
            }
            else if(poolStatus == PoolStatus.PRE_LISTING || poolStatus == PoolStatus.PRE_LAUNCH || poolStatus == PoolStatus.PRE_LAUNCH_DEPOSIT_DISABLED){
                return true;
            }
            else if(poolStatus == PoolStatus.PARTIALLY_LAUNCHED){
                return tokenAllocation.refundableNativeAmount > 0;
            }
            return false;
        }else if(userDeposit > 0){
            return (poolStatus == PoolStatus.PRE_LISTING || poolStatus == PoolStatus.PRE_LAUNCH || poolStatus == PoolStatus.PRE_LAUNCH_DEPOSIT_DISABLED || poolStatus == PoolStatus.NOT_QUALIFIED); 
        }
        return false;
    }
}