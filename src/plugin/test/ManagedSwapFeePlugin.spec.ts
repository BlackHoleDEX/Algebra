import { expect } from './shared/expect';
import { ethers } from 'hardhat';
import { Wallet, AbiCoder, keccak256 } from 'ethers'
import { ManagedSwapFeeTest } from '../typechain';
import { loadFixture, time } from '@nomicfoundation/hardhat-network-helpers';
import snapshotGasCost from './shared/snapshotGasCost';

describe('ManagedSwapFee', () => {
  let wallet: Wallet, other: Wallet;
  let managedSwapFeePlugin: ManagedSwapFeeTest;
  let pluginData: string;

  async function managedSwapFeeFixture() {
    const factory = await ethers.getContractFactory('ManagedSwapFeeTest');
    return (await factory.deploy()) as any as ManagedSwapFeeTest;
  }

  beforeEach('deploy ManagedSwapFeeTest', async () => {
    [wallet, other] = await (ethers as any).getSigners();
    managedSwapFeePlugin = await loadFixture(managedSwapFeeFixture);
  });

  describe('#getManagedFee', () => {
    beforeEach('set config', async () => {
      let provider = ethers.provider
      const block = await provider.getBlock('latest');

      let nonce ="0x0000000000000000000000000000000000000000000000000000000000000001"
      let fee = 1000
      let user = wallet.address
      let expireTime = block!.timestamp + 1000

      let hash = keccak256(AbiCoder.defaultAbiCoder().encode(
        ['bytes32', 'uint24', 'address', 'uint32'],
        [nonce, fee, user, expireTime])
      );

      const hashBytes = Buffer.from(hash.slice(2), 'hex');
      let signature = await wallet.signMessage(hashBytes);

      pluginData = AbiCoder.defaultAbiCoder().encode(
        ['tuple(bytes32, uint24, address, uint32, bytes)'],
        [[nonce, fee, user, expireTime, signature]]
      );
      await managedSwapFeePlugin.setWhitelistStatus(wallet.address, true);

    });

    it('fee is used on swap', async () => {
      await managedSwapFeePlugin.connect(wallet).getFeeForSwap(pluginData)
    });

    it('gas cost', async () => {
      await snapshotGasCost(managedSwapFeePlugin.getGasCostOfGetFeeForSwap(pluginData));
    });

  });

});