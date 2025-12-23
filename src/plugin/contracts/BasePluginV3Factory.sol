// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './interfaces/IBasePluginV3Factory.sol';
import './libraries/AdaptiveFee.sol';
import './AlgebraBasePluginV3.sol';

/// @title Algebra Integral 1.2 default plugin factory
/// @notice This contract creates Algebra adaptive fee plugins for Algebra liquidity pools
/// @dev This plugin factory can only be used for Algebra base pools
contract BasePluginV3Factory is IBasePluginV3Factory {
  /// @inheritdoc IBasePluginV3Factory
  bytes32 public constant override ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR = keccak256('ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR');

  /// @inheritdoc IBasePluginV3Factory
  address public immutable override algebraFactory;

  /// @inheritdoc IBasePluginV3Factory
  AlgebraFeeConfiguration public override defaultFeeConfiguration; // values of constants for sigmoids in fee calculation formula

  /// @inheritdoc IBasePluginV3Factory
  address public override farmingAddress;

  /// @inheritdoc IBasePluginV3Factory
  address public override securityRegistry;

  /// @inheritdoc IBasePluginV3Factory
  mapping(address poolAddress => address pluginAddress) public override pluginByPool;

  /// @inheritdoc IBasePluginV3Factory
  address public override feeDiscountRegistry;

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

  function createPluginForExistingCustomPool(address token0, address token1, address customPoolDeployer) external returns (address) {
    IAlgebraFactory factory = IAlgebraFactory(algebraFactory);
    require(msg.sender == customPoolDeployer || factory.hasRoleOrOwner(factory.POOLS_ADMINISTRATOR_ROLE(), msg.sender), 'Only deployer or admin');
    require(token0 != token1);
    (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    require(token0 != address(0));
    require(customPoolDeployer != address(0), 'Custom pool deployer is required');
    address pool = factory.customPoolByPair(customPoolDeployer, token0, token1);
    require(pool != address(0), 'Pool not exist');

    return _createPlugin(pool);
  }

  function _createPlugin(address pool) internal returns (address) {
    require(pluginByPool[pool] == address(0), 'Already created');
    address plugin = address(new AlgebraBasePluginV3(pool, algebraFactory, address(this), defaultFeeConfiguration, feeDiscountRegistry));
    ISecurityPlugin(plugin).setSecurityRegistry(securityRegistry);
    pluginByPool[pool] = plugin;
    return plugin;
  }

  /// @inheritdoc IBasePluginV3Factory
  function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig) external override onlyAdministrator {
    AdaptiveFee.validateFeeConfiguration(newConfig);
    defaultFeeConfiguration = newConfig;
    emit DefaultFeeConfiguration(newConfig);
  }

  /// @inheritdoc IBasePluginV3Factory
  function setFarmingAddress(address newFarmingAddress) external override onlyAdministrator {
    require(farmingAddress != newFarmingAddress);
    farmingAddress = newFarmingAddress;
    emit FarmingAddress(newFarmingAddress);
  }

  /// @inheritdoc IBasePluginV3Factory
  function setSecurityRegistry(address _securityRegistry) external override onlyAdministrator {
    require(securityRegistry != _securityRegistry);
    securityRegistry = _securityRegistry;
    emit SecurityRegistry(_securityRegistry);
  }

  /// @inheritdoc IBasePluginV3Factory
  function setFeeDiscountRegistry(address newFeeDiscountRegistry) external override onlyAdministrator {
    require(feeDiscountRegistry != newFeeDiscountRegistry);
    feeDiscountRegistry = newFeeDiscountRegistry;
    emit FeeDiscountRegistry(newFeeDiscountRegistry);
  }
}
