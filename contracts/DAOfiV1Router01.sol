pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Factory.sol';
import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Pair.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/IDAOfiV1Router01.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';
import './libraries/DAOfiV1Library.sol';
import './libraries/SafeMath.sol';
import './Power.sol';

contract DAOfiV1Router01 is IDAOfiV1Router01, Power {
    using SafeMath for uint;
    using SafeMath for uint8;
    using SafeMath for uint32;
    using SafeMath for uint256;

    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'DAOfiV1Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'DAOfiV1Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'DAOfiV1Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1, m, n, fee)),
            hex'6a2dbde525d74120f78de7646d79785d9db48aaba527b33804ceb6078e4e5ed2' // init code hash
        ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IDAOfiV1Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // get params
    function getCurveParams(address factory, address tokenA, address tokenB) internal view returns (bytes memory) {
        return IDAOfiV1Pair(pairFor(factory, tokenA, tokenB)).getCurveParams();
    }

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
    ) external virtual override ensure(deadline) returns (uint256 amountBase) {
        if (IDAOfiV1Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IDAOfiV1Factory(factory).createPair(tokenA, tokenB, tokenA, msg.sender, m, n, fee);
        }
        address pair = DAOfiV1Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountAIn);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountBIn);
        amountBase = IDAOfiV1Pair(pair).deposit(to);
    }

    function addLiquidityETH(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        uint256 amountTokenIn,
        uint256 amountETHIn,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint256 amountBase) {
        if (IDAOfiV1Factory(factory).getPair(token, WETH) == address(0)) {
            IDAOfiV1Factory(factory).createPair(token, WETH, token, msg.sender, m, n, fee);
        }
        address pair = DAOfiV1Library.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountTokenIn);
        IWETH(WETH).deposit{value: amountETHIn}();
        assert(IWETH(WETH).transfer(pair, amountETHIn));
        amountBase = IDAOfiV1Pair(pair).deposit(to);
        // refund dust eth, if any
        if (msg.value > amountETHIn) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETHIn);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountBase, uint amountQuote) {
        address pair = DAOfiV1Library.pairFor(factory, tokenA, tokenB);
        (amountBase, amountQuote) = IDAOfiV1Pair(pair).close(to);
    }

    function removeLiquidityETH(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        address pair = DAOfiV1Library.pairFor(factory, token, WETH);
        (amountToken, amountETH) = IDAOfiV1Pair(pair).close(to);
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = DAOfiV1Library.sortTokens(input, output);
            IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveIn, uint reserveOut) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveIn);
            amountOutput = getAmountOut(amountInput, reserveIn, reserveOut, input, output);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? DAOfiV1Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, DAOfiV1Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swap(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'DAOfiV1Router: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(DAOfiV1Library.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swap(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'DAOfiV1Router: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, DAOfiV1Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swap(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    /**** LIBRARY */
    function quote(uint256 amountBaseIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountQuoteOut)
    {
        return DAOfiV1Library.quote(amountBaseIn, factory, tokenA, tokenB, m, n, fee);
    }

    function base(uint256 amountQuoteIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountBaseOut)
    {
        return DAOfiV1Library.base(amountQuoteIn, factory, tokenA, tokenB, m, n, fee);
    }

    function getBaseOut(uint256 amountQuoteIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountBaseOut)
    {
        return DAOfiV1Library.getBaseOut(amountQuoteIn, factory, tokenA, tokenB, m, n, fee);
    }

    function getQuoteOut(uint256 amountBaseIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountQuoteOut)
    {
        return DAOfiV1Library.getQuoteOut(amountBaseIn, factory, tokenA, tokenB, m, n, fee);
    }

    function getBaseIn(uint256 amountQuoteOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountBaseIn)
    {
        return DAOfiV1Library.getBaseIn(amountQuoteOut, factory, tokenA, tokenB, m, n, fee);
    }

    function getQuoteIn(uint256 amountBaseOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountQuoteIn)
    {
        return DAOfiV1Library.getQuoteIn(amountBaseOut, factory, tokenA, tokenB, m, n, fee);
    }

    function getAmountsOut(uint256 amountIn, factory, address[] memory path)
        public view override returns (uint256[] memory amounts)
    {
        return DAOfiV1Library.getAmountsOut(amountIn, factory, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public view override returns (uint256[] memory amounts)
    {
        return DAOfiV1Library.getAmountsIn(amountOut, factory, path);
    }
}
