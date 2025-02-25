// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IGenesisPool.sol";
import "./interfaces/IGanesisPoolBase.sol";

contract GenesisPool is IGenesisPool, IGanesisPoolBase {

    using SafeERC20 for IERC20;

    TokenAllocation public allocationInfo;
    TokenIncentiveInfo public incentiveInfo;
    GenesisInfo public genesisInfo;
    ProtocolInfo public protocolInfo;
    PoolStatus public poolStatus;
    LiquidityPool public liquidityPoolInfo;

    address[] public depositers;
    mapping(address => uint256) public userDeposits;

    constructor(address factory, address genesisManager, address nativeToken, address fundingToken){
        
    }


}