pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

interface IDAOfiV1Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB, address tokenA, address tokenB) external view returns (uint256 amountB);
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, address tokenA, address tokenB) external view returns (uint256 amountOut);
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, address tokenA, address tokenB) external view returns (uint256 amountIn);
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint[] memory amounts);

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
    ) external returns (uint256 amountA, uint256 amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        uint256 amountTokenIn,
        uint256 amountETHIn,
        address to,
        uint deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
}
