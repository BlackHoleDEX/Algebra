// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-periphery/contracts/interfaces/IAlgebraCustomPoolEntryPoint.sol';
import './interfaces/IAlgebraALMCustomPoolDeployer.sol';
import './libraries/AdaptiveFee.sol';
import './AlgebraBasePluginALM.sol';

/// @title Algebra Integral 1.2.1 ALM custom plugin deployer
contract AlgebraALMCustomPoolDeployer is IAlgebraALMCustomPoolDeployer {
  /// @inheritdoc IAlgebraALMCustomPoolDeployer
  bytes32 public constant override ALGEBRA_CUSTOM_PLUGIN_ADMINISTRATOR = keccak256('ALGEBRA_CUSTOM_PLUGIN_ADMINISTRATOR');

  /// @inheritdoc IAlgebraALMCustomPoolDeployer
  address public immutable override algebraFactory;

  /// @inheritdoc IAlgebraALMCustomPoolDeployer
  address public immutable entryPoint;

  /// @inheritdoc IAlgebraALMCustomPoolDeployer
  AlgebraFeeConfiguration public override defaultFeeConfiguration; // values of constants for sigmoids in fee calculation formula

  /// @inheritdoc IAlgebraALMCustomPoolDeployer
  mapping(address poolAddress => address pluginAddress) public override pluginByPool;

  modifier onlyAdministrator() {
    require(IAlgebraFactory(algebraFactory).hasRoleOrOwner(ALGEBRA_CUSTOM_PLUGIN_ADMINISTRATOR, msg.sender), 'Only administrator');
    _;
  }

  constructor(address _algebraFactory, address _entryPoint) {
    entryPoint = _entryPoint;
    algebraFactory = _algebraFactory;
    defaultFeeConfiguration = AdaptiveFee.initialFeeConfiguration();
  }

  /// @inheritdoc IAlgebraPluginFactory
  function beforeCreatePoolHook(address pool, address, address, address, address, bytes calldata) external override returns (address) {
    require(msg.sender == entryPoint);
    return _createPlugin(pool);
  }

  /// @inheritdoc IAlgebraPluginFactory
  function afterCreatePoolHook(address, address, address) external view override {
    require(msg.sender == entryPoint);
  }

  function _createPlugin(address pool) internal returns (address) {
    require(pluginByPool[pool] == address(0), 'Already created');
    address plugin = address(new AlgebraBasePluginALM(pool, algebraFactory, address(this), defaultFeeConfiguration));
    pluginByPool[pool] = plugin;
    return address(plugin);
  }
  
  /// @inheritdoc IAlgebraALMCustomPoolDeployer
  function createCustomPool(address creator, address tokenA, address tokenB, bytes calldata data) external returns (address customPool) {
    return IAlgebraCustomPoolEntryPoint(entryPoint).createCustomPool(address(this), creator, tokenA, tokenB, data);
  }

  /// @inheritdoc IAlgebraALMCustomPoolDeployer
  function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig) external override onlyAdministrator {
    AdaptiveFee.validateFeeConfiguration(newConfig);
    defaultFeeConfiguration = newConfig;
    emit DefaultFeeConfiguration(newConfig);
  }

}