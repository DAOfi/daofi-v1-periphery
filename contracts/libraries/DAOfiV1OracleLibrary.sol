// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Pair.sol';
// import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

// library with helper methods for oracles that are concerned with computing average prices
library DAOfiV1OracleLibrary {
    // using FixedPoint for *;

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(
        address pair
    ) internal view returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) {
        // blockTimestamp = currentBlockTimestamp();
        // price0Cumulative = IDAOfiV1Pair(pair).price0CumulativeLast();
        // price1Cumulative = IDAOfiV1Pair(pair).price1CumulativeLast();

        // // if time has elapsed since the last update on the pair, mock the accumulated price values
        // (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast) = IDAOfiV1Pair(pair).getReserves();
        // if (blockTimestampLast != blockTimestamp) {
        //     // subtraction overflow is desired
        //     uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        //     // addition overflow is desired
        //     // counterfactual
        //     // price0Cumulative += uint(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
        //     // // counterfactual
        //     // price1Cumulative += uint(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
        // }
    }
}
