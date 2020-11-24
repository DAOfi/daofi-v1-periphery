import { ethers } from 'ethers'
import DAOfiV1Pair from '@daofi/daofi-v1-core/build/contracts/DAOfiV1Pair.sol/DAOfiV1Pair.json'
const { keccak256 } = ethers.utils;
const bytecode = `${DAOfiV1Pair.bytecode}`
console.log(`DAOfiV1Pair hashed bytecode: ${keccak256(bytecode)}`)