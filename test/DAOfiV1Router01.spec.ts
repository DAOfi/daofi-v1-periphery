import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { BigNumber, Contract } from 'ethers'
import { ethers } from 'hardhat'
import { DAOfiV1Fixture, getFixtureWithParams } from './shared/fixtures'
import { expandTo18Decimals, getReserveForStartPrice, send } from './shared/utilities'
import { MockProvider } from '@ethereum-waffle/provider';

const zero = ethers.BigNumber.from(0)
const MaxUint256 = ethers.constants.MaxUint256

const provider = new MockProvider();

let walletFixture: DAOfiV1Fixture
let routerFixture: DAOfiV1Fixture
let wallet: SignerWithAddress

const zeros = (numZeros: number) => ''.padEnd(numZeros, '0');

describe('DAOfiV1Router01: m = 1, n = 1, fee = 3', () => {
  async function addLiquidity(baseReserve: BigNumber, quoteReserve: BigNumber) {
    const { tokenBase, tokenQuote, pair } = walletFixture
    if (baseReserve.gt(zero)) await tokenBase.transfer(pair.address, baseReserve)
    if (quoteReserve.gt(zero)) await tokenQuote.transfer(pair.address, quoteReserve)
    await pair.deposit(wallet.address)
  }

  beforeEach(async function () {
    wallet = (await ethers.getSigners())[0]
    walletFixture = await getFixtureWithParams(wallet, 1e6, 1, 3)
    routerFixture = await getFixtureWithParams(wallet, 1e6, 1, 3, false)
  })

  it('addLiquidity: base only', async () => {
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)

    await tokenBase.approve(router.address, baseSupply)
    await tokenQuote.approve(router.address, zero)
    await expect(router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: zero,
      m: 1e6,
      n: 1,
      fee: 3
    }, MaxUint256))
      .to.emit(pair, 'Deposit')
      .withArgs(router.address, baseSupply, zero, zero, wallet.address)
  })

  it('addLiquidity: base and quote', async () => {
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9) // total supply
    const quoteReserveFloat = getReserveForStartPrice(10, 1, 1, 1) // 50
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)
    const expectedBaseOutput = ethers.BigNumber.from('10000000000000000000')
    const expectedBaseReserve = baseSupply.sub(expectedBaseOutput)

    await tokenBase.approve(router.address, baseSupply)
    await tokenQuote.approve(router.address, quoteReserve)
    await expect(router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      m: 1e6,
      n: 1,
      fee: 3
    }, MaxUint256))
      .to.emit(pair, 'Deposit')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, expectedBaseOutput, wallet.address)
  })

  it.only('removeLiquidity:', async () => {
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)
    const quoteReserveFloat = getReserveForStartPrice(10, 1, 1, 1)
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)
    const expectedBaseOutput = ethers.BigNumber.from('10000000000000000000')
    const expectedBaseReserve = baseSupply.sub(expectedBaseOutput)

    // TODO create 712 signature
    const DOMAIN_SEPARATOR = await router.DOMAIN_SEPARATOR();
    console.log(DOMAIN_SEPARATOR)

    interface removeLiquidityMessage {
      sender: string;
      to: string;
      nonce: number;
      deadline: number | string;
    }

    interface Domain {
      name: string;
      version: string;
      chainId: number;
      verifyingContract: string;
    }

    const EIP712Domain = [
      { name: "name", type: "string" },
      { name: "version", type: "string" },
      { name: "chainId", type: "uint256" },
      { name: "verifyingContract", type: "address" },
    ];

    const domain: Domain = { name: 'DAOfiV1Router01', version: '1', chainId: 77, verifyingContract: router.address };
    const nonce = await router.nonces(wallet.address);
    const hexNonce = nonce.toHexString()
    //let nonce = res.data.nonce.hex.toString();
    let count = 66 - hexNonce.length
    let formatNonce = `${'0x'}${zeros(count)}${hexNonce.substr(2)}`

    console.log('nonce: '+formatNonce)

    let sender = wallet.address
    let to = wallet.address
    //
    const message: removeLiquidityMessage = {
      sender: wallet.address,
      to: wallet.address,
      nonce: nonce,
      deadline: MaxUint256.toString()
    };

    let typedData = {
      "types": {
        "EIP712Domain":[
          {"name":"name","type":"string"},
          {"name":"version","type":"string"},
          {"name":"chainId","type":"uint256"},
          {"name":"verifyingContract","type":"address"}
        ],
        "Permit": [
          { "name": "sender", "type": "address" },
          { "name": "to", "type": "address" },
          { "name": "nonce", "type": "uint256" },
          { "name": "deadline", "type": "uint256" }
        ],
      },
      primaryType: "Permit",
      domain: { "name": 'DAOfiV1Router01', "version": '1', "chainId": 77, "verifyingContract": router.address },
      message: {
        "sender": wallet.address,
        "to": wallet.address,
        "nonce": parseInt(nonce.toString()),
        "deadline": MaxUint256.toString()
      }
    }
    console.log(typedData)
    let test = {
      "types":{
        "EIP712Domain":[
          {"name":"name","type":"string"},
          {"name":"version","type":"string"},
          {"name":"chainId","type":"uint256"},
          {"name":"verifyingContract","type":"address"}
        ],"Person":[
          {"name":"name","type":"string"},
          {"name":"wallet","type":"address"}
        ],"Mail":[
          {"name":"from","type":"Person"},
          {"name":"to","type":"Person"},
          {"name":"contents","type":"string"}
        ]
      },
      "primaryType":"Mail",
      "domain":{
        "name":"Ether Mail",
        "version":"1",
        "chainId":1,
        "verifyingContract":"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
      },
      "message":{
        "from":{
          "name":"Cow",
          "wallet":"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
        },
        "to":{
          "name":"Bob",
          "wallet":"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
        },
        "contents":"Hello, Bob!"
      }
    }
    console.log(nonce)
    //console.log(test)
    //const typeDataString = JSON.stringify(typedData)
    //console.log(typeDataString)
    const params = JSON.stringify([wallet.address, typedData])
    let fruits: any[] = [wallet.address, typedData];
    const result = await ethers.provider.send('eth_signTypedData', [wallet.address, typedData])
    const resultFormat = {
      r: result.slice(0, 66),
      s: '0x' + result.slice(66, 130),
      v: parseInt(result.slice(130, 132), 16),
    }
    //const result = await send(wallet.provider, 'eth_signTypedData', fruits)
    console.log(resultFormat)
    console.log(wallet.address)

    let typhash = await router.METATX_TYPEHASH()
    console.log(typhash)

    await tokenBase.approve(router.address, baseSupply)
    await tokenQuote.approve(router.address, quoteReserve)
    await router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      m: 1e6,
      n: 1,
      fee: 3
    }, MaxUint256)

    const lp = {
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      m: 1e6,
      n: 1,
      fee: 3  
    }
    const rp = {
      v: resultFormat.v,
      r: resultFormat.r,
      s: resultFormat.s,
      nonce: parseInt(nonce.toString())
    }
    await expect(router.removeLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      m: 1e6,
      n: 1,
      fee: 3
    }, rp, MaxUint256))
      .to.emit(pair, 'Withdraw')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, wallet.address)
    expect(await tokenBase.balanceOf(wallet.address)).to.eq(baseSupply)
    expect(await tokenQuote.balanceOf(wallet.address)).to.eq(await tokenQuote.totalSupply())
    expect(await tokenBase.balanceOf(pair.address)).to.eq(zero)
    expect(await tokenQuote.balanceOf(pair.address)).to.eq(zero)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(zero)
    expect(reserves[1]).to.eq(zero)
  })

  it('basePrice:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50)) // 50 quote reserve = price 10
    const quotePrice = ethers.BigNumber.from('10000000000000000000') // price 10
    expect(await router.basePrice(tokenBase.address, tokenQuote.address, 1e6, 1, 3)).to.eq(quotePrice)
  })

  it('quotePrice:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50)) // 50 quote reserve = price 10
    const basePrice = ethers.BigNumber.from('100000000000000000') // price 0.10
    expect(await router.quotePrice(tokenBase.address, tokenQuote.address, 1e6, 1, 3)).to.eq(basePrice)
  })

  it('getBaseOut:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    await addLiquidity(expandTo18Decimals(1e9), zero)
    const quoteAmountIn = expandTo18Decimals(50)
    const baseAmountOut = ethers.BigNumber.from('10000000000000000000')
    expect(await router.getBaseOut(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3)).to.eq(
      baseAmountOut
    )
  })

  it('getQuoteOut:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    // need a starting price to sell base for quote
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50)) // 50 quote reserve = price 10
    const baseAmountIn = ethers.BigNumber.from('10000000000000000000')
    const quoteAmountOut = ethers.BigNumber.from('49900000000000000000')
    expect(await router.getQuoteOut(baseAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3)).to.eq(
      quoteAmountOut
    )
  })

  it('swap: quote for base and back to quote', async () => {
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)

    await tokenBase.approve(router.address, baseSupply)
    await tokenQuote.approve(router.address, zero)
    await router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: zero,
      m: 1e6,
      n: 1,
      fee: 3
    }, MaxUint256)

    const quoteAmountIn = expandTo18Decimals(50)
    const baseAmountOut = await router.getBaseOut(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3)

    await tokenQuote.approve(router.address, quoteAmountIn)
    await expect(router.swapExactTokensForTokens({
      sender: wallet.address,
      to: wallet.address,
      tokenIn: tokenQuote.address,
      tokenOut: tokenBase.address,
      amountIn: quoteAmountIn,
      amountOut: baseAmountOut,
      m: 1e6,
      n: 1,
      fee: 3
    }, MaxUint256))
      .to.emit(tokenBase, 'Transfer')
      .withArgs(pair.address, wallet.address, baseAmountOut)
      .to.emit(pair, 'Swap')
      .withArgs(router.address, 0, quoteAmountIn, baseAmountOut, 0, wallet.address)
  })
})
