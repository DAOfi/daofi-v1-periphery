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
                hex'b907b8879232355ebc0b89d3dbe4e012a20544e957d8c1f6f25d5c3420ace3b1' // init code hash
            ))));
    }
}
