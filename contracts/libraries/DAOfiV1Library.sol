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
                hex'fb6ba27c5cbf10f9bf61363287c16068349fba5ae567580326ef74e15c3f5b4a' // init code hash
            ))));
    }
}
