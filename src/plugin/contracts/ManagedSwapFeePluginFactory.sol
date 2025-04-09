// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './ManagedSwapFeeBasePlugin.sol';
import './interfaces/IManagedSwapFeeBasePluginFactory.sol';

/// @title Managed Swap Fee Base Plugin Factory
/// @notice Factory contract for creating ManagedSwapFeeBasePlugin instances
/// @dev Implements the IManagedSwapFeeBasePluginFactory interface
contract ManagedSwapFeeBasePluginFactory is IManagedSwapFeeBasePluginFactory {
    /// @inheritdoc IManagedSwapFeeBasePluginFactory
    bytes32 public constant override ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR = keccak256('ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR');

    /// @inheritdoc IManagedSwapFeeBasePluginFactory
    address public immutable override algebraFactory;

    /// @inheritdoc IManagedSwapFeeBasePluginFactory
    address public override farmingAddress;

    /// @inheritdoc IManagedSwapFeeBasePluginFactory
    mapping(address poolAddress => address pluginAddress) public override pluginByPool;

    /// @inheritdoc IManagedSwapFeeBasePluginFactory
    AlgebraFeeConfiguration public override defaultFeeConfiguration; // values of constants for sigmoids in fee calculation formula

    /// @notice The default router address used during plugin creation
    address public override defaultRouter;

    /// @notice Emitted when the default router address is updated
    /// @param previousRouter The previous default router address
    /// @param newRouter The new default router address
    event DefaultRouterUpdated(address indexed previousRouter, address indexed newRouter);

    modifier onlyAdministrator() {
        require(IAlgebraFactory(algebraFactory).hasRoleOrOwner(ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR, msg.sender), 'Only administrator');
        _;
    }

    constructor(address _algebraFactory) {
        algebraFactory = _algebraFactory;
        defaultFeeConfiguration = AdaptiveFee.initialFeeConfiguration();
        emit DefaultFeeConfiguration(defaultFeeConfiguration);
    }

    /// @inheritdoc IAlgebraPluginFactory
    function beforeCreatePoolHook(address pool, address, address, address, address, bytes calldata) external override returns (address) {
        require(msg.sender == algebraFactory);
        return _createPlugin(pool);
    }

    /// @inheritdoc IAlgebraPluginFactory
    function afterCreatePoolHook(address, address, address) external view override {
        require(msg.sender == algebraFactory);
    }

    /// @inheritdoc IManagedSwapFeeBasePluginFactory
    function createPluginForExistingPool(address token0, address token1) external override returns (address plugin) {
        IAlgebraFactory factory = IAlgebraFactory(algebraFactory);
        require(factory.hasRoleOrOwner(factory.POOLS_ADMINISTRATOR_ROLE(), msg.sender), 'Not authorized');

        address pool = factory.poolByPair(token0, token1);
        require(pool != address(0), 'Pool does not exist');

        return _createPlugin(pool);
    }

    function _createPlugin(address pool) internal returns (address) {
        require(pluginByPool[pool] == address(0), 'Already created');
        IDynamicFeeManager volatilityOracle = new ManagedSwapFeeBasePlugin(pool, algebraFactory, address(this), defaultFeeConfiguration, defaultRouter);
        pluginByPool[pool] = address(volatilityOracle);
        return address(volatilityOracle);
    }

    /// @inheritdoc IManagedSwapFeeBasePluginFactory
    function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig) external override onlyAdministrator {
        AdaptiveFee.validateFeeConfiguration(newConfig);
        defaultFeeConfiguration = newConfig;
        emit DefaultFeeConfiguration(newConfig);
    }

    /// @inheritdoc IManagedSwapFeeBasePluginFactory
    function setFarmingAddress(address newFarmingAddress) external override onlyAdministrator {
        require(farmingAddress != newFarmingAddress, 'Same address');
        farmingAddress = newFarmingAddress;
        emit FarmingAddress(newFarmingAddress);
    }

    /// @notice Sets the router address
    /// @param newRouter The new default router address
    function setRouterAddress(address newRouter) external override onlyAdministrator {
        require(newRouter != address(0), 'Invalid router address');
        defaultRouter = newRouter;
        emit DefaultRouter(newRouter);
    }
}