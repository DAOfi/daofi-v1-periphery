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
  m: number,
  n: number,
  fee: number,
  fromWallet: boolean = true
): Promise<DAOfiV1Fixture> {

  const Token = await ethers.getContractFactory("ERC20")
  const XDai = await ethers.getContractFactory("WxDAI")
  const weth = await ethers.getContractFactory("WETH10")
  const Router = await ethers.getContractFactory("DAOfiV1Router01")

  // deploy tokens
  const tokenBase = await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000')) //1e9 tokens with 18
  const tokenQuote =  await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000'))
  const xDAI = await XDai.deploy()
  const WETH = await weth.deploy()

  // deploy factory
  const formula = await deployContract(wallet, BancorFormula as any)
  const factory = await deployContract(wallet, DAOfiV1Factory, [formula.address])

  // deploy router
  const router = await Router.deploy(factory.address, WETH.address)

  // initialize
  const controller = fromWallet ? wallet.address : router.address
  await factory.createPair(controller, tokenBase.address, tokenQuote.address, wallet.address, m, n, fee)
  const pairAddress = await factory.getPair(tokenBase.address, tokenQuote.address, m, n, fee)
  const pair = new Contract(pairAddress, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)

  // init eth pair
  await factory.createPair(controller, tokenBase.address, WETH.address, wallet.address, m, n, fee)
  const pairAddressETH = await factory.getPair(tokenBase.address, WETH.address, m, n, fee)
  const pairETH = new Contract(pairAddressETH, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)

  await factory.createPair(controller, tokenBase.address, xDAI.address, wallet.address, m, n, fee)
  const xDAIPairAddress = await factory.getPair(tokenBase.address, xDAI.address, m, n, fee)
  const xDAIPair = new Contract(xDAIPairAddress, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)

  return {
    tokenBase,
    tokenQuote,
    xDAI,
    factory,
    router,
    pair,
    xDAIPair,
    WETH,
    pairETH,
  }
}

