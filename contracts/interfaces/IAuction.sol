// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IGanesisPoolBase.sol";

interface IAuction {
    function getLPTokensShares(address[] memory depositers, uint256[] memory deposits, address protocolOwner, uint256 liquidity) external view returns(address[] memory , uint256[] memory);  
    function getProtcolTokenAmount(uint256 startPrice, uint256 depositAmount, IGanesisPoolBase.TokenAllocation memory tokenAllocation) external view returns (uint256); 
}
