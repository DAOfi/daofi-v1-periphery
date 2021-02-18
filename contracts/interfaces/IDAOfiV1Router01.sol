// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

interface IDAOfiV1Router01 {
    struct SwapParams {
        address sender; // Override the message sender, used for permit pattern
        address to; // Recipient of the swap
        address tokenIn; // The input token address, base or quote
        address tokenOut; // The output token address, base or quote (input != output)
        uint256 amountIn; // The amount of token input
        uint256 amountOut; // The amount of token output
        address tokenBase; // The base token address of the pair
        address tokenQuote; // The quote token address of the pair
        uint32 slopeNumerator; // The pair's numerator value (1-1000)
        uint32 n; // The pair's n value (1-3)
        uint32 fee; // The pair's fee value (0-10)
    }

    struct LiquidityParams {
        address sender; // Override the message sender, used for permit pattern
        address to; // Recipient of the initial base supply
        address tokenBase; // The base token address of the pair
        address tokenQuote; // The quote token address of the pair
        uint256 amountBase; // The pair's total base reserve
        uint256 amountQuote; // The pair's initial quote reserve
        uint32 slopeNumerator; // The pair's numerator value (1-1000)
        uint32 n; // The pair's n value (1-3)
        uint32 fee; // The pair's fee value (0-10)
    }

    function factory() external view returns (address);

    function WXDAI() external view returns (address);

    function addLiquidity(
        LiquidityParams calldata lp,
        uint deadline
    ) external returns (uint256 amountBase);

    function addLiquidityXDAI(
        LiquidityParams calldata lp,
        uint deadline
    ) external payable returns (uint256 amountBase);

    function removeLiquidity(
        LiquidityParams calldata lp,
        uint deadline
    ) external returns (uint256 amountBase, uint256 amountQuote);

    function removeLiquidityXDAI(
        LiquidityParams calldata lp,
        uint deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        SwapParams calldata sp,
        uint deadline
    ) external;

    // function swapExactXDAIForTokens(uint256 amountOutMin, bytes[] calldata path, address to, uint deadline)
    //     external
    //     payable;

    // function swapExactTokensForXDAI(
    //     uint256 amountIn,
    //     uint256 amountOutMin,
    //     bytes[] calldata path,
    //     address sender,
    //     address to,
    //     uint deadline
    // ) external;

    function basePrice(address tokenBase, address tokenQuote, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 price);

    function quotePrice(address tokenBase, address tokenQuote, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 price);

    function getBaseOut(uint256 amountQuoteIn, address tokenBase, address tokenQuote, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountBaseOut);

    function getQuoteOut(uint256 amountBaseIn, address tokenBase, address tokenQuote, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountQuoteOut);
}
