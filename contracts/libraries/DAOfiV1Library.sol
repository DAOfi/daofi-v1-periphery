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
                hex'491d572950d14dc00dd2a7804fc3fbfa8d2de6c5c7c067bf84b373541f67eb43' // init code hash
            ))));
    }
}
