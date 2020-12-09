// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

library DAOfiV1Library {
    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenBase, address tokenQuote, uint32 m, uint32 n, uint32 fee)
        internal pure returns (address pair)
    {
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(tokenBase, tokenQuote, m, n, fee)),
                hex'8f132b9f11c1722648a46d8a5d51d966908af560237f4c2d5ea0bc40379a3007' // init code hash
            ))));
    }
}
