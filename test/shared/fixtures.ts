import { Wallet, Contract } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './utilities'

import DAOfiV1Factory from '@daofi/daofi-v1-core/build/DAOfiV1Factory.json'
import IDAOfiV1Pair from '@daofi/daofi-v1-core/build/IDAOfiV1Pair.json'

import ERC20 from '../../build/ERC20.json'
import WETH9 from '../../build/WETH9.json'
import DAOfiV1Router01 from '../../build/DAOfiV1Router01.json'

const overrides = {
  gasLimit: 9999999
}

interface DAOfiV1Fixture {
  token0: Contract
  token1: Contract
  tokenBase: Contract
  WETH: Contract
  WETHPartner: Contract
  factory: Contract
  router: Contract
  pair: Contract
  WETHPair: Contract
}

export async function getFixtureWithParams(provider: Web3Provider, [wallet]: Wallet[], m: number, n: number, fee: number): Promise<DAOfiV1Fixture> {
  // deploy tokens
  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])
  const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])
  const WETH = await deployContract(wallet, WETH9)
  const WETHPartner = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])

  // deploy factory
  const factory = await deployContract(wallet, DAOfiV1Router01, [])

  // deploy router
  const router = await deployContract(wallet, DAOfiV1Router01, [factory.address, WETH.address], overrides)

  // initialize
  await factory.createPair(tokenA.address, tokenB.address, tokenA.address, wallet.address, m, n, fee)
  const pairAddress = await factory.getPair(tokenA.address, tokenB.address, m, n, fee)
  const pair = new Contract(pairAddress, JSON.stringify(IDAOfiV1Pair.abi), provider).connect(wallet)

  const token0Address = await pair.token0()
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA
  const tokenBase = tokenA

  await factory.createPair(WETH.address, WETHPartner.address, WETHPartner.address, wallet.address, m, n, fee)
  const WETHPairAddress = await factory.getPair(WETH.address, WETHPartner.address, m, n, fee)
  const WETHPair = new Contract(WETHPairAddress, JSON.stringify(IDAOfiV1Pair.abi), provider).connect(wallet)

  return {
    token0,
    token1,
    tokenBase,
    WETH,
    WETHPartner,
    factory,
    router,
    pair,
    WETHPair
  }
}
