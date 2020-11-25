import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { BigNumber, Contract } from 'ethers'
import { ethers } from 'hardhat'
import { getFixtureWithParams } from './shared/fixtures'
import { expandTo18Decimals, getReserveForStartPrice } from './shared/utilities'

const zero = ethers.BigNumber.from(0)

let tokenBase: Contract
let tokenQuote: Contract
let xDAI: Contract
let xDAIPartner: Contract
let factory: Contract
let router: Contract
let pair: Contract
let xDAIPair: Contract
let wallet: SignerWithAddress

describe('DAOfiV1Router01: m = 1, n = 1, fee = 3', () => {
  async function addLiquidity(baseReserve: BigNumber, quoteReserve: BigNumber) {
    if (baseReserve.gt(zero)) await tokenBase.transfer(pair.address, baseReserve)
    if (quoteReserve.gt(zero)) await tokenQuote.transfer(pair.address, quoteReserve)
    await pair.deposit(wallet.address)
  }

  beforeEach(async function () {
    wallet = (await ethers.getSigners())[0]
    const fixture = await getFixtureWithParams(wallet, 1e6, 1, 3)
    tokenBase = fixture.tokenBase
    tokenQuote = fixture.tokenQuote
    xDAI = fixture.xDAI
    xDAIPartner = fixture.xDAIPartner
    factory = fixture.factory
    router = fixture.router
    pair = fixture.pair
    xDAIPair = fixture.xDAIPair
  })

  it('basePrice', async () => {
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50)) // 50 quote reserve = price 10
    const quotePrice = ethers.BigNumber.from('9998000000000000000') // price 10
    expect(await router.basePrice(tokenBase.address, tokenQuote.address, 1e6, 1, 3)).to.eq(quotePrice)
  })

  it('quotePrice', async () => {
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50)) // 50 quote reserve = price 10
    const basePrice = ethers.BigNumber.from('100000000000000000') // price 0.10
    expect(await router.quotePrice(tokenBase.address, tokenQuote.address, 1e6, 1, 3)).to.eq(basePrice)
  })

  it('getBaseOut', async () => {
    await addLiquidity(expandTo18Decimals(1e9), zero)
    const quoteAmountIn = expandTo18Decimals(50)
    const baseAmountOut = ethers.BigNumber.from('9984000000000000000')
    expect(await router.getBaseOut(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3)).to.eq(
      baseAmountOut
    )
  })

  it('getQuoteOut', async () => {
    // need a starting price to sell base for quote
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50)) // 50 quote reserve = price 10
    const baseAmountIn = ethers.BigNumber.from('100000000000000000')
    const quoteAmountOut = ethers.BigNumber.from('49999999999951030035')
    expect(await router.getQuoteOut(baseAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3)).to.eq(
      quoteAmountOut
    )
  })
})
