// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import '@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol';
import '@cryptoalgebra/integral-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '../interfaces/IERC20.sol';


contract AlgebraPoolAPI is Initializable {

    IAlgebraFactory public algebraFactory;
    INonfungiblePositionManager public nonfungiblePositionManager;

    struct PoolInfo {
        // pair info
        address pair_address; 			// pair contract address
        string symbol; 				    // pair symbol
        string name;                    // pair name
        uint decimals; 			        // pair decimals
        bool stable; 				    // pair pool type (stable = false, means it's a variable type of pool)
        uint total_supply; 			    // pair tokens supply

        // token pair info
        address token0;
        address token1;
        string token0_symbol;
        string token1_symbol;
        uint8 token0_decimals;
        uint8 token1_decimals;
        int24 tickSpacing;

        // Pool State
        uint160 sqrtPriceX96; // Current price
        int24 tick;           // Current tick
        uint128 liquidity;    // Current *active* liquidity in the pool
        uint16 fee;

        // Fee Growth (Global)
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;

        // User Specific (Limited)
        uint256 account_token0_balance;
        uint256 account_token1_balance;
    }

    // Struct to hold detailed information about an NFT position
    struct PositionInfo {
        uint256 tokenId;
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0; // Fees owed as of last action
        uint128 tokensOwed1; // Fees owed as of last action
        // Current claimable fees (calculated via staticcall to collect)
        uint256 claimableFee0;
        uint256 claimableFee1;
        // Optional: Add token symbols/decimals if needed, similar to PoolInfo
        string token0_symbol;
        string token1_symbol;
        uint8 token0_decimals;
        uint8 token1_decimals;
    }

    address public owner;

    event Owner(address oldOwner, address newOwner);
    event FactoryChanged(address indexed oldFactory, address indexed newFactory);
    event NonfungiblePositionManagerChanged(address indexed oldManager, address indexed newManager);

    function initialize(address _factory, address _nonfungiblePositionManager) public initializer {
        require(_factory != address(0), "Zero address: factory");
        require(_nonfungiblePositionManager != address(0), "Zero address: position manager");
        algebraFactory = IAlgebraFactory(_factory);
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
    }

    /// @notice Fetches information for multiple Algebra pools based on their addresses.
    /// @param _pools Array of pool addresses to query.
    /// @param _user Address of the user for whom to fetch token balances (can be address(0)).
    /// @return infos Array of PoolInfo structs for the provided pool addresses. Invalid/uninitialized pools will have default values.
    function getAllPoolInfo(address[] calldata _pools, address _user)
        external
        view
        returns (PoolInfo[] memory infos)
    {
        uint256 numPools = _pools.length;
        infos = new PoolInfo[](numPools);

        for (uint i = 0; i < numPools; i++) {
            address pool = _pools[i];
            // Check if the address is valid and the pool appears initialized
            // A zero address or uninitialized pool will result in default PoolInfo struct values
            if (pool != address(0)) {
                try IAlgebraPool(pool).token0() returns (address token0Addr) {
                    // Check if token0 is non-zero, indicating initialization
                    if (token0Addr != address(0)) {
                         infos[i] = _poolAddressToInfo(pool, _user);
                    }
                    // If token0 is zero, infos[i] remains default (zeroed)
                } catch {
                    // Handle cases where the address is not a contract or doesn't implement token0()
                    // infos[i] remains default (zeroed)
                }
            }
        }
    }

    /// @notice Fetches information for a single Algebra pool.
    /// @param _pool Address of the Algebra pool contract.
    /// @param _user Address of the user for whom to fetch token balances (can be address(0)).
    /// @return info PoolInfo struct for the pool.
    function getPoolInfo(address _pool, address _user)
        external
        view
        returns (PoolInfo memory info)
    {
        require(_pool != address(0), "Zero address: pool");
        // Basic check if pool seems initialized
        require(IAlgebraPool(_pool).token0() != address(0), "Pool not initialized or invalid");
        info = _poolAddressToInfo(_pool, _user);
    }


    /// @notice Internal function to gather data for a specific pool address.
    function _poolAddressToInfo(address _pool, address _user)
        internal
        view
        returns (PoolInfo memory info)
    {
        IAlgebraPool pool = IAlgebraPool(_pool);

        info.pair_address = _pool;
        info.token0 = pool.token0();
        info.token1 = pool.token1();
        info.tickSpacing = pool.tickSpacing();
        info.liquidity = pool.liquidity();

        // Read globalState (slot0)
        (info.sqrtPriceX96, info.tick, info.fee, , , ) = pool.globalState();

        // Read fee growth globals
        info.feeGrowthGlobal0X128 = pool.totalFeeGrowth0Token();
        info.feeGrowthGlobal1X128 = pool.totalFeeGrowth1Token();

        // Get Token Info - Wrap in safe calls if tokens might not implement standard ERC20/might revert
        info.token0_symbol = _safeGetSymbol(info.token0);
        info.token1_symbol = _safeGetSymbol(info.token1);
        info.token0_decimals = _safeGetDecimals(info.token0);
        info.token1_decimals = _safeGetDecimals(info.token1);

        // Get User Balances (if user address provided)
        if (_user != address(0)) {
            info.account_token0_balance = IERC20(info.token0).balanceOf(_user);
            info.account_token1_balance = IERC20(info.token1).balanceOf(_user);
        } else {
            info.account_token0_balance = 0;
            info.account_token1_balance = 0;
        }
    }

     /// @notice Sorts two token addresses.
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "Tokens must be different");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /// @notice Fetches detailed information for multiple NFT positions.
    /// @param _tokenIds An array of NFT token IDs to query.
    /// @return positionsInfo An array of PositionInfo structs containing details for each requested tokenId.
    function getAllPositionsInfo(uint256[] calldata _tokenIds)
        external
        view
        returns (PositionInfo[] memory positionsInfo)
    {
        require(address(nonfungiblePositionManager) != address(0), "Manager not set");
        uint256 numTokenIds = _tokenIds.length;
        positionsInfo = new PositionInfo[](numTokenIds);

        for (uint i = 0; i < numTokenIds; i++) {
            uint256 tokenId = _tokenIds[i];
            positionsInfo[i].tokenId = tokenId;

            // 1. Get base position data
            (
                ,
                ,
                positionsInfo[i].token0,
                positionsInfo[i].token1,
                ,
                positionsInfo[i].tickLower,
                positionsInfo[i].tickUpper,
                positionsInfo[i].liquidity,
                ,
                ,
                ,
            ) = nonfungiblePositionManager.positions(tokenId);

            // 2. Get current claimable fees via staticcall to collect
            // We use type(uint128).max to request the maximum possible amount
            (bool success, bytes memory result) = address(nonfungiblePositionManager).staticcall(
                abi.encodeWithSelector(
                    INonfungiblePositionManager.collect.selector,
                    INonfungiblePositionManager.CollectParams({
                        tokenId: tokenId,
                        recipient: address(this), // recipient doesn't matter for staticcall view
                        amount0Max: type(uint128).max,
                        amount1Max: type(uint128).max
                    })
                )
            );

            if (success && result.length >= 64) { // Expecting two uint256 values
                (positionsInfo[i].claimableFee0, positionsInfo[i].claimableFee1) = abi.decode(result, (uint256, uint256));
            } else {
                // Handle potential revert from staticcall (e.g., token ID doesn't exist)
                // Keep claimable fees as 0 or revert the whole call, depending on desired behavior.
                // Here, we'll just leave them as 0. Consider adding error handling if needed.
                positionsInfo[i].claimableFee0 = 0;
                positionsInfo[i].claimableFee1 = 0;
            }

             // 3. (Optional) Get token symbols and decimals
             // This adds extra external calls, increasing gas cost further.
             // Only include if necessary for the API consumer.
             positionsInfo[i].token0_symbol = _safeGetSymbol(positionsInfo[i].token0);
             positionsInfo[i].token1_symbol = _safeGetSymbol(positionsInfo[i].token1);
             positionsInfo[i].token0_decimals = _safeGetDecimals(positionsInfo[i].token0);
             positionsInfo[i].token1_decimals = _safeGetDecimals(positionsInfo[i].token1);
        }
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner, 'not owner');
        require(_owner != address(0), 'zeroAddr');
        owner = _owner;
        emit Owner(msg.sender, _owner);
    }

    /// @notice Updates the Algebra Factory address (onlyOwner).
    function setFactory(address _newFactory) external {
        require(msg.sender == owner, 'not owner');
        require(_newFactory != address(0), "Zero address: new factory");
        address oldFactory = address(algebraFactory);
        algebraFactory = IAlgebraFactory(_newFactory);
        emit FactoryChanged(oldFactory, _newFactory);
    }

    /// @notice Updates the Nonfungible Position Manager address (onlyOwner).
    function setNonfungiblePositionManager(address _newManager) external {
        require(msg.sender == owner, 'not owner');
        require(_newManager != address(0), "Zero address: new manager");
        address oldManager = address(nonfungiblePositionManager);
        nonfungiblePositionManager = INonfungiblePositionManager(_newManager);
        emit NonfungiblePositionManagerChanged(oldManager, _newManager);
    }
}
