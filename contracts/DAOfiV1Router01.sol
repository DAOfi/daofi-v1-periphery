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

contract DAOfiV1Router01 is IDAOfiV1Router01 {
    using SafeMath for uint;
    using SafeMath for uint8;
    using SafeMath for uint32;
    using SafeMath for uint256;

    struct CurveParams {
        address pairOwner;
        address baseToken;
        uint32 m;
        uint32 n;
        uint32 fee;
        uint256 s;
    }

    struct SwapParams {
        address token;
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
    ) external override ensure(deadline) returns (uint256 amountBase) {
        if (IDAOfiV1Factory(factory).getPair(tokenA, tokenB, m, n, fee) == address(0)) {
            IDAOfiV1Factory(factory).createPair(tokenA, tokenB, tokenA, msg.sender, m, n, fee);
        }
        address pair = DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee);
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
    ) external override payable ensure(deadline) returns (uint256 amountBase) {
        if (IDAOfiV1Factory(factory).getPair(token, WETH, m, n, fee) == address(0)) {
            IDAOfiV1Factory(factory).createPair(token, WETH, token, msg.sender, m, n, fee);
        }
        address pair = DAOfiV1Library.pairFor(factory, token, WETH, m, n, fee);
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
    ) public override ensure(deadline) returns (uint amountBase, uint amountQuote) {
        address pair = DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee);
        (amountBase, amountQuote) = IDAOfiV1Pair(pair).close(to);
    }

    function removeLiquidityETH(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountToken, uint amountETH) {
        address pair = DAOfiV1Library.pairFor(factory, token, WETH, m, n, fee);
        (amountToken, amountETH) = IDAOfiV1Pair(pair).close(to);
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(bytes[] memory path, address _to) internal {
        for (uint i; i < path.length - 1; i++) {
            SwapParams memory spIn = abi.decode(path[i], (SwapParams));
            SwapParams memory spOut = abi.decode(path[i + 1], (SwapParams));
            IDAOfiV1Pair pair = IDAOfiV1Pair(
                DAOfiV1Library.pairFor(factory,  spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee)
            );
            uint256 amountBaseOutput;
            uint256 amountQuoteOutput;
            { // scope to avoid stack too deep errors
            (uint reserveBase, uint reserveQuote,) = pair.getReserves();
            CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
            if (params.baseToken == spOut.token) {
                uint256 amountInput = IERC20(spIn.token).balanceOf(address(pair)).sub(reserveQuote).mul(1000 - params.fee) / 1000;
                amountBaseOutput = pair.getBaseOut(amountInput);
            } else {
                uint256 amountInput = IERC20(spIn.token).balanceOf(address(pair)).sub(reserveBase).mul(1000 - params.fee) / 1000;
                amountQuoteOutput = pair.getQuoteOut(amountInput);
            }
            }
            address to = _to;
            if (i < path.length - 2) {
                SwapParams memory spNext = abi.decode(path[i + 2], (SwapParams));
                to = DAOfiV1Library.pairFor(factory, spOut.token, spNext.token, spOut.m, spOut.n, spOut.fee);
            }
            pair.swap(
                amountBaseOutput,
                amountQuoteOutput,
                to,
                new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        bytes[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) {
        SwapParams memory spIn = abi.decode(path[0], (SwapParams));
        SwapParams memory spOut = abi.decode(path[1], (SwapParams));
        TransferHelper.safeTransferFrom(
            spIn.token, msg.sender, DAOfiV1Library.pairFor(factory, spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee), amountIn
        );
        SwapParams memory spFinal = abi.decode(path[path.length - 1], (SwapParams));
        uint balanceBefore = IERC20(spFinal.token).balanceOf(to);
        _swap(path, to);
        require(
            IERC20(spFinal.token).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        bytes[] calldata path,
        address to,
        uint deadline
    ) external override payable ensure(deadline) {
        SwapParams memory spIn = abi.decode(path[0], (SwapParams));
        require(spIn.token == WETH, 'DAOfiV1Router: INVALID_PATH');
        SwapParams memory spOut = abi.decode(path[1], (SwapParams));
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(
            DAOfiV1Library.pairFor(factory, spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee),
            amountIn
        ));
        SwapParams memory spFinal = abi.decode(path[path.length - 1], (SwapParams));
        uint balanceBefore = IERC20(spFinal.token).balanceOf(to);
        _swap(path, to);
        require(
            IERC20(spFinal.token).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        bytes[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) {
        SwapParams memory spFinal = abi.decode(path[path.length - 1], (SwapParams));
        require(spFinal.token == WETH, 'DAOfiV1Router: INVALID_PATH');
        SwapParams memory spIn = abi.decode(path[0], (SwapParams));
        SwapParams memory spOut = abi.decode(path[1], (SwapParams));
        TransferHelper.safeTransferFrom(
            spIn.token,
            msg.sender,
            DAOfiV1Library.pairFor(factory, spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee),
            amountIn
        );
        _swap(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    function getBaseOut(uint256 amountQuoteIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountBaseOut)
    {
        return IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getBaseOut(amountQuoteIn);
    }

    function getQuoteOut(uint256 amountBaseIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountQuoteOut)
    {
        return IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getQuoteOut(amountBaseIn);
    }

    function getBaseIn(uint256 amountQuoteOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountBaseIn)
    {
        return IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getBaseIn(amountQuoteOut);
    }

    function getQuoteIn(uint256 amountBaseOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountQuoteIn)
    {
        return IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getQuoteIn(amountBaseOut);
    }

    function getAmountsOut(uint256 amountIn, bytes[] memory path)
        public view override returns (uint256[] memory amounts)
    {
        require(path.length >= 2, 'DAOfiV1Router: INVALID_PATH');
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            SwapParams memory spIn = abi.decode(path[i], (SwapParams));
            SwapParams memory spOut = abi.decode(path[i + 1], (SwapParams));
            address pair = DAOfiV1Library.pairFor(factory, spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee);
            CurveParams memory params = abi.decode(IDAOfiV1Pair(pair).getCurveParams(), (CurveParams));
            uint256 amountInWithFees = amounts[i].mul(1000 - params.fee) / 1000;
            if (params.baseToken == spOut.token) {
                amounts[i + 1] = IDAOfiV1Pair(pair).getBaseOut(amountInWithFees);
            } else {
                amounts[i + 1] = IDAOfiV1Pair(pair).getQuoteOut(amountInWithFees);
            }
        }
    }

    function getAmountsIn(uint256 amountOut, bytes[] memory path)
        public view override returns (uint256[] memory amounts)
    {
        require(path.length >= 2, 'DAOfiV1Router: INVALID_PATH');
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            SwapParams memory spIn = abi.decode(path[i - 1], (SwapParams));
            SwapParams memory spOut = abi.decode(path[i], (SwapParams));
            address pair = DAOfiV1Library.pairFor(factory, spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee);
            CurveParams memory params = abi.decode(IDAOfiV1Pair(pair).getCurveParams(), (CurveParams));
            if (params.baseToken == spOut.token) {
                amounts[i - 1] = IDAOfiV1Pair(pair).getQuoteIn(amounts[i]).mul(1000 + params.fee) / 1000;
            } else {
                amounts[i - 1] = IDAOfiV1Pair(pair).getBaseIn(amounts[i]).mul(1000 + params.fee) / 1000;
            }
        }
    }
}
