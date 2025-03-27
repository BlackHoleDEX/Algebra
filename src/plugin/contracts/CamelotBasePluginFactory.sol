// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './interfaces/ICamelotBasePluginFactory.sol';
import './libraries/AdaptiveFee.sol';
import './CamelotBasePlugin.sol';

/// @title Algebra Integral 1.2.1 plugin factory
/// @notice This contract creates Camelot base plugins for Algebra liquidity pools
/// @dev This plugin factory can only be used for Algebra base pools
contract CamelotBasePluginFactory is ICamelotBasePluginFactory {
  /// @inheritdoc ICamelotBasePluginFactory
  bytes32 public constant override ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR = keccak256('ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR');

  /// @inheritdoc ICamelotBasePluginFactory
  address public immutable override algebraFactory;

  /// @inheritdoc ICamelotBasePluginFactory
  AlgebraFeeConfiguration public override defaultFeeConfiguration; // values of constants for sigmoids in fee calculation formula

  /// @inheritdoc ICamelotBasePluginFactory
  bool public override dynamicFeeStatus;

  /// @inheritdoc ICamelotBasePluginFactory
  bool public override slidingFeeStatus;

  /// @inheritdoc ICamelotBasePluginFactory
  address public override securityRegistry;

  /// @inheritdoc ICamelotBasePluginFactory
  uint16 public override defaultBaseFee = 3000;

  /// @inheritdoc ICamelotBasePluginFactory
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

  /// @inheritdoc ICamelotBasePluginFactory
  function createPluginForExistingPool(address token0, address token1) external override returns (address) {
    IAlgebraFactory factory = IAlgebraFactory(algebraFactory);
    require(factory.hasRoleOrOwner(factory.POOLS_ADMINISTRATOR_ROLE(), msg.sender));

    address pool = factory.poolByPair(token0, token1);
    require(pool != address(0), 'Pool not exist');

    return _createPlugin(pool);
  }

  function _createPlugin(address pool) internal returns (address) {
    require(pluginByPool[pool] == address(0), 'Already created');
    address plugin = address(new CamelotBasePlugin(pool, algebraFactory, address(this), defaultFeeConfiguration, defaultBaseFee));
    IDynamicFeeManager(plugin).changeDynamicFeeStatus(dynamicFeeStatus);
    ISecurityPlugin(plugin).setSecurityRegistry(securityRegistry);
    ISlidingFeePlugin(plugin).changeSlidingFeeStatus(slidingFeeStatus);
    pluginByPool[pool] = plugin;
    return plugin;
  }

  /// @inheritdoc ICamelotBasePluginFactory
  function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig) external override onlyAdministrator {
    AdaptiveFee.validateFeeConfiguration(newConfig);
    defaultFeeConfiguration = newConfig;
    emit DefaultFeeConfiguration(newConfig);
  }

  /// @inheritdoc ICamelotBasePluginFactory
  function setDynamicFeeStatus(bool status) external override onlyAdministrator {
    require(status != dynamicFeeStatus);
    dynamicFeeStatus = status;
    emit DynamicFeeStatus(status);
  }

  /// @inheritdoc ICamelotBasePluginFactory
  function setSlidingFeeStatus(bool status) external override onlyAdministrator {
    require(status != slidingFeeStatus);
    slidingFeeStatus = status;
    emit SlidingFeeStatus(status);
  }

  /// @inheritdoc ICamelotBasePluginFactory
  function setDefaultBaseFee(uint16 newDefaultBaseFee) external override onlyAdministrator {
    require(defaultBaseFee != newDefaultBaseFee);
    defaultBaseFee = newDefaultBaseFee;
    emit DefaultBaseFee(newDefaultBaseFee);
  } 

  /// @inheritdoc ICamelotBasePluginFactory
  function setSecurityRegistry(address _securityRegistry) external override onlyAdministrator {
    require(securityRegistry != _securityRegistry);
    securityRegistry = _securityRegistry;
    emit SecurityRegistry(_securityRegistry);
  }
}
