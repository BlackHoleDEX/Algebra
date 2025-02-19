// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './interfaces/IBasePluginV5Factory.sol';
import './libraries/AdaptiveFee.sol';
import './AlgebraBasePluginV5.sol';

/// @title Algebra Integral 1.2 default plugin factory
/// @notice This contract creates Algebra v5 plugin for Algebra liquidity pools
/// @dev This plugin factory can only be used for Algebra base pools
contract BasePluginV5Factory is IBasePluginV5Factory {
  /// @inheritdoc IBasePluginV5Factory
  bytes32 public constant override ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR = keccak256('ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR');

  /// @inheritdoc IBasePluginV5Factory
  address public immutable override algebraFactory;

  /// @inheritdoc IBasePluginV5Factory
  AlgebraFeeConfiguration public override defaultFeeConfiguration; // values of constants for sigmoids in fee calculation formula

  /// @inheritdoc IBasePluginV5Factory
  address public override farmingAddress;

  /// @inheritdoc IBasePluginV5Factory
  address public override securityRegistry;

  /// @inheritdoc IBasePluginV5Factory
  address public override feeDiscountRegistry;

  /// @inheritdoc IBasePluginV5Factory
  mapping(address poolAddress => address pluginAddress) public override pluginByPool;

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

  /// @inheritdoc IBasePluginV5Factory
  function createPluginForExistingPool(address token0, address token1) external override returns (address) {
    IAlgebraFactory factory = IAlgebraFactory(algebraFactory);
    require(factory.hasRoleOrOwner(factory.POOLS_ADMINISTRATOR_ROLE(), msg.sender));

    address pool = factory.poolByPair(token0, token1);
    require(pool != address(0), 'Pool not exist');

    return _createPlugin(pool);
  }

  function _createPlugin(address pool) internal returns (address) {
    require(pluginByPool[pool] == address(0), 'Already created');
    address plugin = address(new AlgebraBasePluginV5(pool, algebraFactory, address(this)));
    IDynamicFeeManager(plugin).changeFeeConfiguration(defaultFeeConfiguration);
    IFeeDiscountPlugin(plugin).setFeeDiscountRegistry(feeDiscountRegistry);
    ISecurityPlugin(plugin).setSecurityRegistry(securityRegistry);
    pluginByPool[pool] = plugin;
    return plugin;
  }

  /// @inheritdoc IBasePluginV5Factory
  function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig) external override onlyAdministrator {
    AdaptiveFee.validateFeeConfiguration(newConfig);
    defaultFeeConfiguration = newConfig;
    emit DefaultFeeConfiguration(newConfig);
  }

  /// @inheritdoc IBasePluginV5Factory
  function setFarmingAddress(address newFarmingAddress) external override onlyAdministrator {
    require(farmingAddress != newFarmingAddress);
    farmingAddress = newFarmingAddress;
    emit FarmingAddress(newFarmingAddress);
  }

  /// @inheritdoc IBasePluginV5Factory
  function setSecurityRegistry(address _securityRegistry) external override onlyAdministrator {
    require(securityRegistry != _securityRegistry);
    securityRegistry = _securityRegistry;
    emit SecurityRegistry(_securityRegistry);
  }

  /// @inheritdoc IBasePluginV5Factory
  function setFeeDiscountRegistry(address newFeeDiscountRegistry) external override onlyAdministrator {
    require(feeDiscountRegistry != newFeeDiscountRegistry);
    feeDiscountRegistry = newFeeDiscountRegistry;
    emit FeeDiscountRegistry(newFeeDiscountRegistry);
  }
}
