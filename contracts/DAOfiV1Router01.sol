pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Factory.sol';
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

    struct CurveParams {
        address baseToken;
        uint32 m;
        uint32 n;
        uint32 fee;
    }

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
    function quote(uint amountA, uint reserveA, uint reserveB, address tokenA, address tokenB)
        public
        view
        override
        returns (uint amountB)
    {
        require(amountA > 0, 'DAOfiV1Router: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'DAOfiV1Router: INSUFFICIENT_LIQUIDITY');
        CurveParams memory params = abi.decode(DAOfiV1Library.getCurveParams(factory, tokenA, tokenB), (CurveParams));
        if (tokenB == params.baseToken) {
            amountB = amountA.mul(reserveB).mul(params.m) / reserveA.mul(10 ** 6);
        } else {
            amountB = amountA.mul(reserveB).mul(10 ** 6) / reserveA.mul(params.m);
        }
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, address tokenA, address tokenB)
        public
        view
        override
        returns (uint amountOut)
    {
        require(amountIn > 0, 'DAOfiV1Router: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'DAOfiV1Router: INSUFFICIENT_LIQUIDITY');
        CurveParams memory params = abi.decode(DAOfiV1Library.getCurveParams(factory, tokenA, tokenB), (CurveParams));
        uint amountInWithFee = amountIn.mul(1000 - params.fee);
        if (tokenB == params.baseToken) {
            (uint256 resultA, uint8 precisionA) = power(
                (10 ** 6) * (params.n + 1) * (amountInWithFee + (reserveIn * 1000)),
                (params.m * 1000),
                1,
                uint32(params.n + 1));
            (uint256 resultB, uint8 precisionB) = power(
                (reserveIn * (10 ** 6)),
                (reserveOut * params.m),
                1,
                uint32(params.n));
            amountOut = (resultA >> precisionA) - (resultB >> precisionB);
        } else {
            (uint256 resultA, uint8 precisionA) = power(
                (reserveOut * (10 ** 6)),
                (reserveIn * params.m),
                1,
                uint32(params.n));
            (uint256 resultB, uint8 precisionB) = power(
                ((resultA >> precisionA) * 1000) - amountInWithFee,
                1000,
                uint32(params.n + 1),
                1);
            amountOut = reserveOut - (((resultB >> precisionB) * params.m) / ((10 ** 6) * (params.n + 1)));
        }
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, address tokenA, address tokenB)
        public
        view
        override
        returns (uint amountIn)
    {
        require(amountOut > 0, 'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'DAOfiV1Router: INSUFFICIENT_LIQUIDITY');
        CurveParams memory params = abi.decode(DAOfiV1Library.getCurveParams(factory, tokenA, tokenB), (CurveParams));
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(1000 - params.fee);
        amountIn = (numerator / denominator).add(1);
        if (tokenB == params.baseToken) {
            amountIn = (amountIn * (10 ** 6)) / params.m;
        } else {
            amountIn = (amountIn * params.m) / (10 ** 6);
        }
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        require(path.length >= 2, 'DAOfiV1Router: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = DAOfiV1Library.getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, path[i], path[i + 1]);
        }
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        require(path.length >= 2, 'DAOfiV1Router: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = DAOfiV1Library.getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, path[i - 1], path[i]);
        }
    }
}
