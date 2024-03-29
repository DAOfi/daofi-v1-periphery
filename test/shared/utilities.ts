import { ethers } from 'hardhat'
import { BigNumber, Contract } from 'ethers'
const { getAddress, keccak256, defaultAbiCoder, toUtf8Bytes, solidityPack } = ethers.utils

export const MINIMUM_LIQUIDITY = ethers.BigNumber.from(10).pow(3)

const PERMIT_TYPEHASH = keccak256(
  toUtf8Bytes('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)')
)

export function expandTo18Decimals(n: number): BigNumber {
  return ethers.BigNumber.from(n).mul(ethers.BigNumber.from(10).pow(18))
}

function getDomainSeparator(name: string, tokenAddress: string) {
  return keccak256(
    defaultAbiCoder.encode(
      ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
      [
        keccak256(toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')),
        keccak256(toUtf8Bytes(name)),
        keccak256(toUtf8Bytes('1')),
        1,
        tokenAddress
      ]
    )
  )
}

export async function getApprovalDigest(
  token: Contract,
  approve: {
    owner: string
    spender: string
    value: BigNumber
  },
  nonce: BigNumber,
  deadline: BigNumber
): Promise<string> {
  const name = await token.name()
  const DOMAIN_SEPARATOR = getDomainSeparator(name, token.address)
  return keccak256(
    solidityPack(
      ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
      [
        '0x19',
        '0x01',
        DOMAIN_SEPARATOR,
        keccak256(
          defaultAbiCoder.encode(
            ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256'],
            [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, deadline]
          )
        )
      ]
    )
  )
}

export function getCreate2Address(
  factoryAddress: string,
  tokenBase: string,
  tokenQuote: string,
  slopeNumerator: number,
  n: number,
  fee: number,
  bytecode: string
): string {
  const create2Inputs = [
    '0xff',
    factoryAddress,
    keccak256(solidityPack(['address', 'address', 'uint32', 'uint32', 'uint32'], [tokenBase, tokenQuote, slopeNumerator, n, fee])),
    keccak256(bytecode)
  ]
  const sanitizedInputs = `0x${create2Inputs.map(i => i.slice(2)).join('')}`
  return getAddress(`0x${keccak256(sanitizedInputs).slice(-40)}`)
}

const slopeD = 1e6
// y = mx ** n
// given y = price, solve for x
// then plug x into the antiderivative
// y' = (slopeN * x ** (n + 1)) / (slopeD * (n + 1))
// y' = quote reserve at price
export function getReserveForStartPrice(price: number, slopeN: number, n: number): number {
  const s = (price * (slopeD / slopeN)) ** (1 / n)
  return (slopeN * (s ** (n + 1))) / (slopeD * (n + 1))
}
