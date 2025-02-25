// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import  "./interfaces/IDutchAuction.sol";
import "./interfaces/IGanesisPoolBase.sol";

contract DutchAction is IGanesisPoolBase, OwnableUpgradeable {

    address public _genesisPool;

    constructor() {}

    function initialize(address genesisPool) initializer  public {
        __Ownable_init();

        _genesisPool = genesisPool;
    }

    function getProtcolTokenAmount(uint256 startPrice, uint256 depositAmount, TokenAllocation memory tokenAllocation) external view returns (uint256){
        return (depositAmount * tokenAllocation.proposedNativeAmount) / tokenAllocation.proposedFundingAmount;
    }

    function getLPTokensShares(address[] memory depositers, uint256[] memory deposits, address protocolOwner, uint256 liquidity) external view returns(address[] memory _account , uint256[] memory _amounts) {
        require(_genesisPool == msg.sender, "invalid _genesisPool");
        require(protocolOwner != address(0), "invalid protocolOwner");
        require(liquidity > 0, "invalid liquidity");
        require(depositers.length == deposits.length, "length mistach auction");

        uint256 _totalDeposits = 0;
        uint256 _depositersCnt = depositers.length;
        uint256 i;
        for(i = 0; i < _depositersCnt; i++){
            require(depositers[i] != address(0), "invalid depositer");
            require(deposits[i] > 0, "invalid deposit amount");
            _totalDeposits += deposits[i];
        }

        require(_totalDeposits > 0, "0 total deposits");

        _account = new address[](_depositersCnt + 1); 
        _amounts = new uint256[](_depositersCnt + 1); 

        uint256 _totalAdded = 0;
        uint256 _depositerLiquidity = liquidity / 2;

        for(i = 0; i < _depositersCnt; i++){
            _account[i+1] = depositers[i];
            _amounts[i+1] = (_depositerLiquidity * deposits[i]) / _totalDeposits;
            _totalAdded += _amounts[i+1];
        }

        _account[0] = protocolOwner;
        _amounts[0] = liquidity - _totalAdded;
        
        return (_account, _amounts);
    }

}