// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './AlgebraCommunityVault.sol';
import './interfaces/vault/IAlgebraVaultFactory.sol';

contract AlgebraVaultFactory is IAlgebraVaultFactory {
  address private immutable algebraFactory;
  address public algebraFeeManager;

  address public owner;

  mapping(address => address) public poolToVault;

  event VaultCreatedForPool(address indexed pool, address indexed vaultAddress, address indexed algebraFeeManagerForVault, address caller);

  constructor(address _algebraFactory, address _algebraFeeManager) {
    require(_algebraFactory != address(0), 'ZERO_ALGEBRA_FACTORY_OWNER');
    require(_algebraFeeManager != address(0), 'ZERO_ALGEBRA_FEE_MANAGER');
    algebraFactory = _algebraFactory;
    algebraFeeManager = _algebraFeeManager;
    owner = msg.sender;
  }

  /// @inheritdoc IAlgebraVaultFactory
  function createVaultForPool(
    address poolAddress,
    address creator,
    address, // deployer
    address, // token0
    address // token1
  ) external override returns (address communityFeeVault) {
    require(poolToVault[poolAddress] == address(0), 'VAULT_ALREADY_EXISTS');
    communityFeeVault = address(new AlgebraCommunityVault(algebraFactory, algebraFeeManager));
    poolToVault[poolAddress] = communityFeeVault;
    emit VaultCreatedForPool(poolAddress, communityFeeVault, creator, msg.sender);
  }

  /// @inheritdoc IAlgebraVaultFactory
  function getVaultForPool(address poolAddress) external view override returns (address communityFeeVault) {
    communityFeeVault = poolToVault[poolAddress];
    require(communityFeeVault != address(0), 'VAULT_NOT_FOUND');
  }

  function setAlgebraFeeManager(address _algebraFeeManager) public {
    require(msg.sender == owner, 'NOT_OWNER');
    require(_algebraFeeManager != address(0), 'ZERO_ALGEBRA_FEE_MANAGER');
    algebraFeeManager = _algebraFeeManager;
  }

  function setOwner(address _newOwner) external {
    require(msg.sender == owner, 'NOT_OWNER');
    require(_newOwner != address(0), 'ZERO_ADDRESS');
    owner = _newOwner;
  }
}
