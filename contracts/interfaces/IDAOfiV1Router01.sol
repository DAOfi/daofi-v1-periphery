// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

interface IDAOfiV1Router01 {
    struct CurveParams {
        address pairOwner;
        address baseToken;
        uint32 m;
        uint32 n;
        uint32 fee;
        uint256 s;
    }

    struct SwapParams {
        address sender;
        address to;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint32 m;
        uint32 n;
        uint32 fee;
    }

    struct LiquidityParams {
        address sender;
        address to;
        address tokenBase;
        address tokenQuote;
        uint256 amountBase;
        uint256 amountQuote;
        uint32 m;
        uint32 n;
        uint32 fee;
    }

    function factory() external view returns (address);

    function WETH() external view returns (address);

    function addLiquidity(
        LiquidityParams calldata lp,
        uint deadline
    ) external returns (uint256 amountBase);

    function addLiquidityETH(
        LiquidityParams calldata lp,
        uint deadline
    ) external payable returns (uint256 amountBase);

    function removeLiquidity(
        LiquidityParams calldata lp,
        uint deadline
    ) external returns (uint256 amountBase, uint256 amountQuote);

    function removeLiquidityETH(
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

    function basePrice(address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 price);

    function quotePrice(address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 price);

    function getBaseOut(uint256 amountQuoteIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountBaseOut);

    function getQuoteOut(uint256 amountBaseIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountQuoteOut);

    function getBaseIn(uint256 amountQuoteOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountBaseIn);

    function getQuoteIn(uint256 amountBaseOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountQuoteIn);

    // function getAmountsOut(uint256 amountIn, SwapParams[] calldata path)
    //     external view returns (uint256[] memory amounts);

    // function getAmountsIn(uint256 amountOut, SwapParams[] calldata path)
    //     external view returns (uint256[] memory amounts);
}
