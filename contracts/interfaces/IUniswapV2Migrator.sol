pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

interface IUniswapV2Migrator {
    function migrate(address token, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external;
}
