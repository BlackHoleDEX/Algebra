// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../GanesisPoolBase.sol"; 
import '../interfaces/IGenesisPoolManager.sol';
import {BlackTimeLibrary} from "../libraries/BlackTimeLibrary.sol";

contract GenesisPoolAPI is GanesisPoolBase, Initializable {

    struct GenesisInfo {
        address protocolToken;
        uint256 userDeposit;
        TokenAllocation tokenAllocation;
        TokenIncentiveInfo incentiveInfo;
        GenesisPool genesisPool;
        ProtocolInfo protocolInfo;
        LiquidityPool liquidityPool;
        PoolStatus poolStatus;
    }

    address public owner;
    IGenesisPoolManager public genesisManager;

    uint256 public constant MAX_POOLS = 1000;

    constructor() {}

    function initialize(address _genesisManager) initializer public {
  
        owner = msg.sender;

        genesisManager = IGenesisPoolManager(_genesisManager);
    }


    function getAllGenesisPools(address _user, uint _amounts, uint _offset) external view returns(uint totPairs, bool hasNext, GenesisInfo[] memory genesisPools){
         
        if(_user == address(0)) {
            return (0,false,genesisPools);
        }

        require(_amounts <= MAX_POOLS, 'too many pools');

        genesisPools = new GenesisInfo[](_amounts);

        address[] memory proposedTokens = genesisManager.proposedTokens();
        
        uint i = _offset;
        hasNext = true;
        address proposedToken;

        for(i; i < _offset + _amounts; i++){
            if(i >= totPairs) {
                hasNext = false;
                break;
            }

            proposedToken = proposedTokens[i];

            genesisPools[i - _offset].protocolToken = proposedToken;
            genesisPools[i - _offset].userDeposit = genesisManager.userDeposits(proposedToken, _user);
            genesisPools[i - _offset].tokenAllocation = genesisManager.allocationsInfo(proposedToken);
            genesisPools[i - _offset].incentiveInfo = genesisManager.incentivesInfo(proposedToken);
            genesisPools[i - _offset].genesisPool = genesisManager.genesisPoolsInfo(proposedToken);
            genesisPools[i - _offset].liquidityPool = genesisManager.liquidityPoolsInfo(proposedToken);
            genesisPools[i - _offset].poolStatus = genesisManager.poolsStatus(proposedToken);
        }

    }
   
}