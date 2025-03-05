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

    function getGenesisPool(address _user, address genesisPool) external view returns (GenesisData memory genesisData){
        GenesisInfo memory genesisInfo = IGenesisPool(genesisPool).getGenesisInfo();
        address fundingToken = genesisInfo.fundingToken;
        address nativeToken = genesisInfo.nativeToken;

        genesisData.nativeToken = nativeToken;
        genesisData.nativeTokensDecimal = IERC20(nativeToken).decimals();
        genesisData.fundingTokensDecimal = IERC20(fundingToken).decimals();
        genesisData.nativeToken = genesisInfo.nativeToken;
        genesisData.genesisPool = genesisPool;
        genesisData.userDeposit = IGenesisPool(genesisPool).userDeposits(_user);
        genesisData.tokenAllocation = IGenesisPool(genesisPool).getAllocationInfo();
        genesisData.incentiveInfo = IGenesisPool(genesisPool).getIncentivesInfo();
        genesisData.genesisInfo = genesisInfo;
        genesisData.liquidityPool = IGenesisPool(genesisPool).getLiquidityPoolInfo();
        genesisData.poolStatus = IGenesisPool(genesisPool).poolStatus();
    }

    function getAllGenesisPools(address _user, uint _amounts, uint _offset) external view returns(uint totalPools, bool hasNext, GenesisData[] memory genesisPools){
         
        if(_user == address(0)) {
            return (0,false,genesisPools);
        }

        require(_amounts <= MAX_POOLS, 'too many pools');

        genesisPools = new GenesisData[](_amounts);

        address[] memory proposedTokens = genesisManager.getAllNaitveTokens();
        totalPools = proposedTokens.length;

        uint i = _offset;
        hasNext = true;
        address genesisPool;
        address nativeToken;
        GenesisInfo memory genesisInfo;

        for(i; i < _offset + _amounts; i++){
            if(i >= totalPools) {
                hasNext = false;
                break;
            }

            nativeToken = proposedTokens[i];

            genesisPool = genesisPoolFactory.getGenesisPool(nativeToken);
            genesisInfo = IGenesisPool(genesisPool).getGenesisInfo();

            genesisPools[i - _offset].genesisPool = genesisPool;
            genesisPools[i - _offset].nativeToken = nativeToken;

            genesisPools[i - _offset].nativeTokensDecimal = IERC20(nativeToken).decimals();
            genesisPools[i - _offset].fundingTokensDecimal = IERC20(genesisInfo.fundingToken).decimals();

            genesisPools[i - _offset].userDeposit = IGenesisPool(genesisPool).userDeposits(_user);
            genesisPools[i - _offset].tokenAllocation = IGenesisPool(genesisPool).getAllocationInfo();
            genesisPools[i - _offset].incentiveInfo = IGenesisPool(genesisPool).getIncentivesInfo();
            genesisPools[i - _offset].genesisInfo = genesisInfo;
            genesisPools[i - _offset].liquidityPool = IGenesisPool(genesisPool).getLiquidityPoolInfo();
            genesisPools[i - _offset].poolStatus = IGenesisPool(genesisPool).poolStatus();
        }

    }
   
}