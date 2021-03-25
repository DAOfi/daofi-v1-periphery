import { ethers } from 'ethers'
import { deployContract } from 'ethereum-waffle'
import DAOfiV1Router01 from '../build/contracts/DAOfiV1Router01.sol/DAOfiV1Router01.json'

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.JSONRPC_URL || 'https://kovan.poa.network'
  )
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '', provider)
  console.log('Wallet:', wallet.address)
  const router = await deployContract(
    wallet,
    DAOfiV1Router01,
    [
      // factory kovan
      //'0xf3Fc676c0aa38EC808CA848F081c55f3f03d4810',
      // factory mainnet
      '0xEaC9260C59693f180936779451B996b303a0A488',
      // WETH on kovan
      // '0xa1c74a9a3e59ffe9bee7b85cd6e91c0751289ebd',
      // WETH on mainnet
       '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'
    ],
    {
      chainId: process.env.CHAIN_ID ? parseInt(process.env.CHAIN_ID) : 0x2A, // default to kovan (42)
      gasLimit: 8000000,
      gasPrice: ethers.utils.parseUnits('200', 'gwei')
    }
  )
  console.log('Router deployted at:', router.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
