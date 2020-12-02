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
  xDAIPartner: Contract
  factory: any
  router: Contract
  pair: Contract
  xDAIPair: Contract
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
  const Router = await ethers.getContractFactory("DAOfiV1Router01")

  // deploy tokens
  const tokenA = await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000')) //1e9 tokens with 18
  const tokenB =  await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000'))
  const xDAI = await XDai.deploy()
  const xDAIPartner = await  await Token.deploy(ethers.BigNumber.from('0x033b2e3c9fd0803ce8000000'))

  // deploy factory
  const factory = await deployContract(wallet, DAOfiV1Factory)

  // deploy router
  const router = await Router.deploy(factory.address, xDAI.address, 'DAOfiV1Router01')

  // initialize
  const controller = fromWallet ? wallet.address : router.address
  await factory.createPair(controller, tokenA.address, tokenB.address, tokenA.address, wallet.address, m, n, fee)
  const pairAddress = await factory.getPair(tokenA.address, tokenB.address, m, n, fee)
  const pair = new Contract(pairAddress, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)

  const tokenBase = tokenA
  const tokenQuote = tokenB

  await factory.createPair(controller, xDAI.address, xDAIPartner.address, xDAIPartner.address, wallet.address, m, n, fee)
  const xDAIPairAddress = await factory.getPair(xDAI.address, xDAIPartner.address, m, n, fee)
  const xDAIPair = new Contract(xDAIPairAddress, JSON.stringify(DAOfiV1Pair.abi)).connect(wallet)

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

