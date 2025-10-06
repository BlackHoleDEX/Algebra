pragma solidity =0.8.20;

import './BasePluginV2Factory.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol';
import './interfaces/ICustomPluginV2Factory.sol';
/// @title Algebra Integral 1.2.2 custom plugin factory
/// @notice This contract creates Algebra adaptive fee plugins for Algebra liquidity pools
/// @dev This plugin factory can only be used for Algebra base pools
contract CustomPluginV2Factory is BasePluginV2Factory, ICustomPluginV2Factory {
  constructor(address _algebraFactory) BasePluginV2Factory(_algebraFactory) {}

  /// @inheritdoc ICustomPluginV2Factory
  function createPluginForExistingCustomPool(address token0, address token1, address customPoolDeployer) external override returns (address) {
    IAlgebraFactory factory = IAlgebraFactory(algebraFactory);
    require(msg.sender == customPoolDeployer || factory.hasRoleOrOwner(factory.POOLS_ADMINISTRATOR_ROLE(), msg.sender), 'Only deployer or admin');
    require(token0 != token1);
    (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    require(token0 != address(0));
    address pool = customPoolDeployer == address(0)
      ? factory.poolByPair(token0, token1)
      : factory.customPoolByPair(customPoolDeployer, token0, token1);
    require(pool != address(0), 'Pool not exist');

    return _createPlugin(pool);
  }
}
