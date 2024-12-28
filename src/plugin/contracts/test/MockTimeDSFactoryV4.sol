// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './MockTimeAlgebraBasePluginV4.sol';

import '../interfaces/IBasePluginV4Factory.sol';

import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPluginFactory.sol';

contract MockTimeDSFactoryV4 is IBasePluginV4Factory {
  /// @inheritdoc IBasePluginV4Factory
  bytes32 public constant override ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR = keccak256('ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR');

  address public immutable override algebraFactory;

  /// @inheritdoc IBasePluginV4Factory
  AlgebraFeeConfiguration public override defaultFeeConfiguration; // values of constants for sigmoids in fee calculation formula

  /// @inheritdoc IBasePluginV4Factory
  mapping(address => address) public override pluginByPool;

  /// @inheritdoc IBasePluginV4Factory
  address public override farmingAddress;

  /// @inheritdoc IBasePluginV4Factory
  address public override securityRegistry;

  constructor(address _algebraFactory) {
    algebraFactory = _algebraFactory;
  }

  /// @inheritdoc IAlgebraPluginFactory
  function beforeCreatePoolHook(address pool, address, address, address, address, bytes calldata) external override returns (address) {
    return _createPlugin(pool);
  }

  /// @inheritdoc IAlgebraPluginFactory
  function afterCreatePoolHook(address, address, address) external view override {
    require(msg.sender == algebraFactory);
  }

  function createPluginForExistingPool(address token0, address token1) external override returns (address) {
    IAlgebraFactory factory = IAlgebraFactory(algebraFactory);
    require(factory.hasRoleOrOwner(factory.POOLS_ADMINISTRATOR_ROLE(), msg.sender));

    address pool = factory.poolByPair(token0, token1);
    require(pool != address(0), 'Pool not exist');

    return _createPlugin(pool);
  }

  function setPluginForPool(address pool, address plugin) external {
    pluginByPool[pool] = plugin;
  }

  function _createPlugin(address pool) internal returns (address) {
    MockTimeAlgebraBasePluginV4 plugin = new MockTimeAlgebraBasePluginV4(pool, algebraFactory, address(this));
    IDynamicFeeManager(plugin).changeFeeConfiguration(defaultFeeConfiguration);
    ISecurityPlugin(plugin).setSecurityRegistry(securityRegistry);
    pluginByPool[pool] = address(plugin);
    return address(plugin);
  }

  /// @inheritdoc IBasePluginV4Factory
  function setFarmingAddress(address newFarmingAddress) external override {
    require(farmingAddress != newFarmingAddress);
    farmingAddress = newFarmingAddress;
    emit FarmingAddress(newFarmingAddress);
  }

  /// @inheritdoc IBasePluginV4Factory
  function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig) external override {
    AdaptiveFee.validateFeeConfiguration(newConfig);
    defaultFeeConfiguration = newConfig;
    emit DefaultFeeConfiguration(newConfig);
  }

  /// @inheritdoc IBasePluginV4Factory
  function setSecurityRegistry(address _securityRegistry) external override {
    require(securityRegistry != _securityRegistry);
    securityRegistry = _securityRegistry;
    emit SecurityRegistry(_securityRegistry);
  }
}
