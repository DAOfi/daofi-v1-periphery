// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

interface IDAOfiV1Router01 {
    function factory() external view returns (address);

    function WETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        address baseToken,
        uint32 m,
        uint32 n,
        uint32 fee,
        uint256 amountAIn,
        uint256 amountBIn,
        address to,
        uint deadline
    ) external returns (uint256 amountBase);

    function addLiquidityETH(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        uint256 amountTokenIn,
        uint256 amountETHIn,
        address to,
        uint deadline
    ) external payable returns (uint256 amountBase);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline
    ) external returns (uint256 amountBase, uint256 amountQuote);

    function removeLiquidityETH(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        bytes[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokens(uint256 amountOutMin, bytes[] calldata path, address to, uint deadline)
        external
        payable;

    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, bytes[] calldata path, address to, uint deadline)
        external;

    function getBaseOut(uint256 amountQuoteIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountBaseOut);

    function getQuoteOut(uint256 amountBaseIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountQuoteOut);

    function getBaseIn(uint256 amountQuoteOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountBaseIn);

    function getQuoteIn(uint256 amountBaseOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view returns (uint256 amountQuoteIn);

    function getAmountsOut(uint256 amountIn, bytes[] calldata path)
        external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, bytes[] calldata path)
        external view returns (uint256[] memory amounts);
}