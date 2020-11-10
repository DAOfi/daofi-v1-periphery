pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import './IUniswapV2Router02.sol';

interface IUniswapV2Router03 is IUniswapV2Router02 {
    function quoteWithParams(uint amountA, uint reserveA, uint reserveB, address tokenA, address tokenB) external view returns (uint amountB);
    function getAmountOutWithParams(uint amountIn, uint reserveIn, uint reserveOut, address tokenA, address tokenB) external view returns (uint amountOut);
    function getAmountInWithParams(uint amountOut, uint reserveIn, uint reserveOut, address tokenA, address tokenB) external view returns (uint amountIn);
    function getAmountsOutWithParams(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsInWithParams(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}
