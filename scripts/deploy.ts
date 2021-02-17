import { ethers } from 'ethers'
import { deployContract } from 'ethereum-waffle'
import DAOfiV1Router01 from '../build/contracts/DAOfiV1Router01.sol/DAOfiV1Router01.json'

const kovanID = 0x2a
const xdaiID = 0x4d

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.JSONRPC_URL || 'https://kovan.poa.network'
  )
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '', provider)
  console.log('wallet', wallet.address)
  const router = await deployContract(
    wallet,
    DAOfiV1Router01,
    [
      // factory
      '0xEfeEfC37727912bF7d6E568E3E0130477EB5f236',
      // WXDAI
      //'0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d',
      // WETH
      '0xCD2090f4D87aA335FC9D64d98BaD032648527b68'
    ],
    {
      chainId: process.env.CHAIN_ID ? parseInt(process.env.CHAIN_ID) : kovanID,
      gasLimit: 9999999,
      gasPrice: ethers.utils.parseUnits('120', 'gwei')
    }
  )
  console.log('deployed router', router.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
