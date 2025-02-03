import { ethers } from 'hardhat';
import { MockFactory, MockPool, MockTimeAlgebraBasePluginV1, MockTimeAlgebraBasePluginV2, MockTimeDSFactoryV2, MockTimeDSFactory, BasePluginV1Factory, BasePluginV2Factory } from '../../typechain';
import { AlgebraFeeDiscountPlugin, FeeDiscountPluginFactory, FeeDiscountRegistry } from '../../typechain';
type Fixture<T> = () => Promise<T>;
interface MockFactoryFixture {
  mockFactory: MockFactory;
}
export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

async function mockFactoryFixture(): Promise<MockFactoryFixture> {
  const mockFactoryFactory = await ethers.getContractFactory('MockFactory');
  const mockFactory = (await mockFactoryFactory.deploy()) as any as MockFactory;

  return { mockFactory };
}

interface PluginFixture extends MockFactoryFixture {
  plugin: MockTimeAlgebraBasePluginV1 | MockTimeAlgebraBasePluginV2;
  mockPluginFactory: MockTimeDSFactory | MockTimeDSFactoryV2;
  mockPool: MockPool;
}

// Monday, October 5, 2020 9:00:00 AM GMT-05:00
export const TEST_POOL_START_TIME = 1601906400;
export const TEST_POOL_DAY_BEFORE_START = 1601906400 - 24 * 60 * 60;

export const pluginFixture: Fixture<PluginFixture> = async function (): Promise<PluginFixture> {
  const { mockFactory } = await mockFactoryFixture();
  //const { token0, token1, token2 } = await tokensFixture()

  const mockPluginFactoryFactory = await ethers.getContractFactory('MockTimeDSFactory');
  const mockPluginFactory = (await mockPluginFactoryFactory.deploy(mockFactory)) as any as MockTimeDSFactory;

  const mockPoolFactory = await ethers.getContractFactory('MockPool');
  const mockPool = (await mockPoolFactory.deploy()) as any as MockPool;

  await mockPluginFactory.beforeCreatePoolHook(mockPool, ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, '0x');
  const pluginAddress = await mockPluginFactory.pluginByPool(mockPool);

  const mockDSOperatorFactory = await ethers.getContractFactory('MockTimeAlgebraBasePluginV1');
  const plugin = mockDSOperatorFactory.attach(pluginAddress) as any as MockTimeAlgebraBasePluginV1;

  return {
    plugin,
    mockPluginFactory,
    mockPool,
    mockFactory,
  };
};

interface PluginFactoryFixture extends MockFactoryFixture {
  pluginFactory: BasePluginV1Factory | BasePluginV2Factory;
}

export const pluginFactoryFixture: Fixture<PluginFactoryFixture> = async function (): Promise<PluginFactoryFixture> {
  const { mockFactory } = await mockFactoryFixture();

  const pluginFactoryFactory = await ethers.getContractFactory('BasePluginV1Factory');
  const pluginFactory = (await pluginFactoryFactory.deploy(mockFactory)) as any as BasePluginV1Factory;

  return {
    pluginFactory,
    mockFactory,
  };
};

export const pluginFactoryFixtureV2: Fixture<PluginFactoryFixture> = async function (): Promise<PluginFactoryFixture> {
  const { mockFactory } = await mockFactoryFixture();

  const pluginFactoryFactory = await ethers.getContractFactory('BasePluginV2Factory');
  const pluginFactory = (await pluginFactoryFactory.deploy(mockFactory)) as any as BasePluginV2Factory;

  return {
    pluginFactory,
    mockFactory,
  };
};


export const pluginFixtureV2: Fixture<PluginFixture> = async function (): Promise<PluginFixture> {
  const { mockFactory } = await mockFactoryFixture();
  //const { token0, token1, token2 } = await tokensFixture()

  const mockPluginFactoryFactory = await ethers.getContractFactory('MockTimeDSFactoryV2');
  const mockPluginFactory = (await mockPluginFactoryFactory.deploy(mockFactory)) as any as MockTimeDSFactoryV2;

  const mockPoolFactory = await ethers.getContractFactory('MockPool');
  const mockPool = (await mockPoolFactory.deploy()) as any as MockPool;

  await mockPluginFactory.beforeCreatePoolHook(mockPool, ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, '0x');
  const pluginAddress = await mockPluginFactory.pluginByPool(mockPool);

  const mockDSOperatorFactory = await ethers.getContractFactory('MockTimeAlgebraBasePluginV2');
  const plugin = mockDSOperatorFactory.attach(pluginAddress) as any as MockTimeAlgebraBasePluginV2;

  return {
    plugin,
    mockPluginFactory,
    mockPool,
    mockFactory,
  };
};

interface FeeDiscountPluginFixture extends MockFactoryFixture {
  plugin: AlgebraFeeDiscountPlugin;
  pluginFactory: FeeDiscountPluginFactory;
  mockPool: MockPool;
  registry: FeeDiscountRegistry;
}

export const feeDiscountPluginFixture: Fixture<FeeDiscountPluginFixture> = async function (): Promise<FeeDiscountPluginFixture> {
  const { mockFactory } = await mockFactoryFixture();
  //const { token0, token1, token2 } = await tokensFixture()

  const pluginFactoryFactory = await ethers.getContractFactory('FeeDiscountPluginFactory');
  const pluginFactory = (await pluginFactoryFactory.deploy(mockFactory)) as any as FeeDiscountPluginFactory;

  const mockPoolFactory = await ethers.getContractFactory('MockPool');
  const mockPool = (await mockPoolFactory.deploy()) as any as MockPool;

  const registryFactory = await ethers.getContractFactory('FeeDiscountRegistry');
  const registry = (await registryFactory.deploy(mockFactory)) as any as FeeDiscountRegistry;

  await pluginFactory.setFeeDiscountRegistry(registry)
  await mockFactory.beforeCreatePoolHook(pluginFactory, mockPool);
  const pluginAddress = await pluginFactory.pluginByPool(mockPool);

  const pluginContractFactory = await ethers.getContractFactory('AlgebraFeeDiscountPlugin');
  const plugin = pluginContractFactory.attach(pluginAddress) as any as AlgebraFeeDiscountPlugin;

  return {
    plugin,
    pluginFactory,
    mockPool,
    registry,
    mockFactory
  };
};