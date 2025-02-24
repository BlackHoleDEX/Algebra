// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../GanesisPoolBase.sol";

interface IDutchAuction {

    function getLPTokensShares(address[] memory depositers, uint256[] memory deposits, address protocolOwner, uint256 liquidity) external view returns(address[] memory _account , uint256[] memory _amounts);  
    function getProtcolTokenAmount(uint256 startPrice, uint256 depositAmount, GanesisPoolBase.TokenAllocation memory tokenAllocation) external view returns (uint256); 
}
