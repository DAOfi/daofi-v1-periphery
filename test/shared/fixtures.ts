import BancorFormula from '@daofi/bancor/solidity/build/contracts/BancorFormula.json'
import DAOfiV1Factory from '@daofi/daofi-v1-core/build/contracts/DAOfiV1Factory.sol/DAOfiV1Factory.json'
import DAOfiV1Pair from '@daofi/daofi-v1-core/build/contracts/DAOfiV1Pair.sol/DAOfiV1Pair.json'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { expandTo18Decimals } from './utilities'

const MaxUint256 = ethers.constants.MaxUint256

export interface Fixture {
  tokenBase: Contract
  tokenQuote: Contract
  xDAI: Contract
  factory: any
  router: Contract
  pair: Contract
}

export async function getTokenFixture(
  wallet: SignerWithAddress,
  slopeNumerator: number = 1e6,
  n: number,
  fee: number,
  quoteAmount: number,
): Promise<Fixture> {

  const Token = await ethers.getContractFactory("ERC20")
  const XDai = await ethers.getContractFactory("WxDAI")
  const Router = await ethers.getContractFactory("DAOfiV1Router01")

  // deploy tokens
  const tokenBase = await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000')) //1e9 tokens with 18
  const tokenQuote =  await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000'))
  const xDAI = await XDai.deploy()

  // deploy factory
  const formula = await deployContract(wallet, BancorFormula as any)
  await formula.init()
  const factory = await deployContract(wallet, DAOfiV1Factory, [formula.address])
  // deploy router
  const router = await Router.deploy(factory.address, xDAI.address)

  // // initialize
  const amountBase = expandTo18Decimals(1e9)
  const amountQuote = expandTo18Decimals(quoteAmount)

  await tokenBase.approve(router.address, amountBase)
  await tokenQuote.approve(router.address, amountQuote)
  await expect(router.addLiquidity({
    sender: wallet.address,
    to: wallet.address,
    tokenBase: tokenBase.address,
    tokenQuote: tokenQuote.address,
    amountBase,
    amountQuote,
    slopeNumerator,
    n,
    fee
  }, MaxUint256)).to.not.be.reverted

  const pairAddress = await factory.getPair(tokenBase.address, tokenQuote.address, slopeNumerator, n, fee)
  const pair = new Contract(pairAddress, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)

  return {
    tokenBase,
    tokenQuote,
    xDAI,
    factory,
    router,
    pair,
  }
}


export async function getXDAIFixture(
  wallet: SignerWithAddress,
  slopeNumerator: number = 1e6,
  n: number,
  fee: number,
  quoteAmount: number,
): Promise<Fixture> {

  const Token = await ethers.getContractFactory("ERC20")
  const XDai = await ethers.getContractFactory("WxDAI")
  const Router = await ethers.getContractFactory("DAOfiV1Router01")

  // deploy tokens
  const tokenBase = await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000')) //1e9 tokens with 18
  const tokenQuote =  await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000'))
  const xDAI = await XDai.deploy()

  // deploy factory
  const formula = await deployContract(wallet, BancorFormula as any)
  await formula.init()
  const factory = await deployContract(wallet, DAOfiV1Factory, [formula.address])
  // deploy router
  const router = await Router.deploy(factory.address, xDAI.address)

  // // initialize
  const amountBase = expandTo18Decimals(1e9)
  const amountQuote = expandTo18Decimals(quoteAmount)
  await tokenBase.approve(router.address, amountBase)

  await expect(router.addLiquidityXDAI({
    sender: wallet.address,
    to: wallet.address,
    tokenBase: tokenBase.address,
    tokenQuote: xDAI.address,
    amountBase,
    amountQuote,
    slopeNumerator,
    n,
    fee
  }, MaxUint256, { value: amountQuote })).to.not.be.reverted

  const pairAddress = await factory.getPair(tokenBase.address, xDAI.address, slopeNumerator, n, fee)
  const pair = new Contract(pairAddress, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)

  return {
    tokenBase,
    tokenQuote,
    xDAI,
    factory,
    router,
    pair,
  }
}
