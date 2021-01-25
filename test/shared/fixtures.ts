import BancorFormula from '@daofi/bancor/solidity/build/contracts/BancorFormula.json'
import DAOfiV1Factory from '@daofi/daofi-v1-core/build/contracts/DAOfiV1Factory.sol/DAOfiV1Factory.json'
import DAOfiV1Pair from '@daofi/daofi-v1-core/build/contracts/DAOfiV1Pair.sol/DAOfiV1Pair.json'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { ethers } from 'hardhat'
import { deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'

export interface DAOfiV1Fixture {
  tokenBase: Contract
  tokenQuote: Contract
  xDAI: Contract
  factory: any
  router: Contract
  pair: Contract
  xDAIPair: Contract
  WETH: Contract
  pairETH: Contract
}

export async function getFixtureWithParams(
  wallet: SignerWithAddress,
  slopeNumerator: number = 1e6,
  n: number,
  fee: number,
  fromWallet: boolean = true
): Promise<any> {

  const Token = await ethers.getContractFactory("ERC20")
  const XDai = await ethers.getContractFactory("WxDAI")
  const weth = await ethers.getContractFactory("WETH10")
  const Router = await ethers.getContractFactory("DAOfiV1Router01")

  // deploy tokens
  const tokenBase = await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000')) //1e9 tokens with 18
  const tokenQuote =  await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000'))
  const xDAI = await XDai.deploy()
  const WETH = await weth.deploy()
  console.log('weth: '+ WETH.address)

  // deploy factory
  const formula = await deployContract(wallet, BancorFormula as any)
  await formula.init()
  console.log('deployed bancor: ', formula.address)
  const factory = await deployContract(wallet, DAOfiV1Factory, [formula.address])
  console.log('deployed factory: ', factory.address)
  // deploy router
  const router = await Router.deploy(factory.address, WETH.address)
  console.log('deployed router: ', router.address)

  // // initialize
  const controller = fromWallet ? wallet.address : router.address
  await factory.createPair(controller, tokenBase.address, tokenQuote.address, wallet.address, slopeNumerator, n, fee)
  console.log('factory crate pair 1')
  const pairAddress = await factory.getPair(tokenBase.address, tokenQuote.address, slopeNumerator, n, fee)
  const pair = new Contract(pairAddress, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)
  console.log('factory get pair 1')
  // // init eth pair
  await factory.createPair(controller, tokenBase.address, WETH.address, wallet.address, slopeNumerator, n, fee)
  const pairAddressETH = await factory.getPair(tokenBase.address, WETH.address, slopeNumerator, n, fee)
  const pairETH = new Contract(pairAddressETH, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)
  console.log('factory crate eth')
  await factory.createPair(controller, tokenBase.address, xDAI.address, wallet.address, slopeNumerator, n, fee)
  const xDAIPairAddress = await factory.getPair(tokenBase.address, xDAI.address, slopeNumerator, n, fee)
  const xDAIPair = new Contract(xDAIPairAddress, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)
  console.log('factory crate pair xadai')
  return {
    tokenBase,
    tokenQuote,
    xDAI,
    factory,
    router,
    pair,
    pairETH,
    WETH
  }
}
