import { Wallet, Contract } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './utilities'

import DAOfiV1Factory from '@daofi/daofi-v1-core/build/DAOfiV1Factory.json'
import IDAOfiV1Pair from '@daofi/daofi-v1-core/build/IDAOfiV1Pair.json'

import ERC20 from '../../build/ERC20.json'
import xDAI9 from '../../build/xDAI9.json'
import DAOfiV1Router01 from '../../build/DAOfiV1Router01.json'

const overrides = {
  gasLimit: 9999999
}

interface DAOfiV1Fixture {
  tokenBase: Contract
  tokenQuote: Contract
  xDAI: Contract
  xDAIPartner: Contract
  factory: Contract
  router: Contract
  pair: Contract
  xDAIPair: Contract
}

export async function getFixtureWithParams(provider: Web3Provider, [wallet]: Wallet[], m: number, n: number, fee: number): Promise<DAOfiV1Fixture> {
  // deploy tokens
  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(1e6)])
  const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(1e6)])
  const xDAI = await deployContract(wallet, xDAI9)
  const xDAIPartner = await deployContract(wallet, ERC20, [expandTo18Decimals(1e6)])

  // deploy factory
  const factory = await deployContract(wallet, DAOfiV1Factory, [])

  // deploy router
  const router = await deployContract(wallet, DAOfiV1Router01, [factory.address, xDAI.address], overrides)

  // initialize
  await factory.createPair(tokenA.address, tokenB.address, tokenA.address, wallet.address, m, n, fee)
  const pairAddress = await factory.getPair(tokenA.address, tokenB.address, m, n, fee)
  const pair = new Contract(pairAddress, JSON.stringify(IDAOfiV1Pair.abi), provider).connect(wallet)

  const tokenBase = tokenA
  const tokenQuote = tokenB

  await factory.createPair(xDAI.address, xDAIPartner.address, xDAIPartner.address, wallet.address, m, n, fee)
  const xDAIPairAddress = await factory.getPair(xDAI.address, xDAIPartner.address, m, n, fee)
  const xDAIPair = new Contract(xDAIPairAddress, JSON.stringify(IDAOfiV1Pair.abi), provider).connect(wallet)

  return {
    tokenBase,
    tokenQuote,
    xDAI,
    xDAIPartner,
    factory,
    router,
    pair,
    xDAIPair
  }
}
