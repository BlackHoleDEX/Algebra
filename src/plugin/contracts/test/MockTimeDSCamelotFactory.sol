// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './MockTimeCamelotBasePlugin.sol';

import '../interfaces/ICamelotBasePluginFactory.sol';

import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPluginFactory.sol';

contract MockTimeDSCamelotFactory is ICamelotBasePluginFactory {
  /// @inheritdoc ICamelotBasePluginFactory
  bytes32 public constant override ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR = keccak256('ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR');

  address public immutable override algebraFactory;

  /// @inheritdoc ICamelotBasePluginFactory
  AlgebraFeeConfiguration public override defaultFeeConfiguration; // values of constants for sigmoids in fee calculation formula

  /// @inheritdoc ICamelotBasePluginFactory
  mapping(address => address) public override pluginByPool;

  /// @inheritdoc ICamelotBasePluginFactory
  bool public override dynamicFeeStatus;

  /// @inheritdoc ICamelotBasePluginFactory
  bool public override slidingFeeStatus;

  uint16 public override defaultBaseFee;

  /// @inheritdoc ICamelotBasePluginFactory
  address public override securityRegistry;

  constructor(address _algebraFactory) {
    algebraFactory = _algebraFactory;
    defaultFeeConfiguration = AdaptiveFee.initialFeeConfiguration();
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
    MockTimeCamelotBasePlugin plugin = new MockTimeCamelotBasePlugin(pool, algebraFactory, address(this), defaultFeeConfiguration, defaultBaseFee);
    IDynamicFeeManager(plugin).changeDynamicFeeStatus(dynamicFeeStatus);
    ISlidingFeePlugin(plugin).changeSlidingFeeStatus(slidingFeeStatus);
    pluginByPool[pool] = address(plugin);
    return address(plugin);
  }

  /// @inheritdoc ICamelotBasePluginFactory
  function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig) external override {
    AdaptiveFee.validateFeeConfiguration(newConfig);
    defaultFeeConfiguration = newConfig;
    emit DefaultFeeConfiguration(newConfig);
  }

  /// @inheritdoc ICamelotBasePluginFactory
  function setDynamicFeeStatus(bool status) external override {
    require(status != dynamicFeeStatus);
    dynamicFeeStatus = status;
    emit DynamicFeeStatus(status);
  }

  /// @inheritdoc ICamelotBasePluginFactory
  function setSlidingFeeStatus(bool status) external override {
    require(status != slidingFeeStatus);
    slidingFeeStatus = status;
    emit SlidingFeeStatus(status);
  }

  /// @inheritdoc ICamelotBasePluginFactory
  function setSecurityRegistry(address _securityRegistry) external override {
    require(securityRegistry != _securityRegistry);
    securityRegistry = _securityRegistry;
    emit SecurityRegistry(_securityRegistry);
  }

  /// @inheritdoc ICamelotBasePluginFactory
  function setDefaultBaseFee(uint16 newDefaultBaseFee) external override {
    require(defaultBaseFee != newDefaultBaseFee);
    defaultBaseFee = newDefaultBaseFee;
    emit DefaultBaseFee(newDefaultBaseFee);
  } 
}
