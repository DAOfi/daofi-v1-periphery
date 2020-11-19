// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Factory.sol';
import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Pair.sol';
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/IDAOfiV1Router01.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWxDAI.sol';
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
    address public immutable override WxDAI;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'DAOfiV1Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WxDAI) {
        factory = _factory;
        WxDAI = _WxDAI;
    }

    receive() external payable {
        assert(msg.sender == WxDAI); // only accept WxDAI via fallback from the WxDAI contract
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
            IDAOfiV1Factory(factory).createPair(address(this), tokenA, tokenB, baseToken, msg.sender, m, n, fee);
        }
        address pair = DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountAIn);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountBIn);
        amountBase = IDAOfiV1Pair(pair).deposit(to);
    }

    function addLiquidityxDAI(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        uint256 amountTokenIn,
        uint256 amountxDAIIn,
        address to,
        uint deadline
    ) external override payable ensure(deadline) returns (uint256 amountBase) {
        if (IDAOfiV1Factory(factory).getPair(token, WxDAI, m, n, fee) == address(0)) {
            IDAOfiV1Factory(factory).createPair(address(this), token, WxDAI, token, msg.sender, m, n, fee);
        }
        address pair = DAOfiV1Library.pairFor(factory, token, WxDAI, m, n, fee);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountTokenIn);
        IWxDAI(WxDAI).deposit{value: amountxDAIIn}();
        assert(IWxDAI(WxDAI).transfer(pair, amountxDAIIn));
        amountBase = IDAOfiV1Pair(pair).deposit(to);
        // refund dust eth, if any
        if (msg.value > amountxDAIIn) TransferHelper.safeTransferETH(msg.sender, msg.value - amountxDAIIn);
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
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee));
        CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
        require(msg.sender == params.pairOwner, 'DAOfiV1Router: FORBIDDEN');
        (amountBase, amountQuote) = pair.withdraw(to);
    }

    function removeLiquidityxDAI(
        address token,
        uint32 m,
        uint32 n,
        uint32 fee,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountToken, uint amountxDAI) {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, token, WxDAI, m, n, fee));
        CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
        require(msg.sender == params.pairOwner, 'DAOfiV1Router: FORBIDDEN');
        (amountToken, amountxDAI) = pair.withdraw(to);
        TransferHelper.safeTransfer(token, to, amountToken);
        IWxDAI(WxDAI).withdraw(amountxDAI);
        TransferHelper.safeTransferETH(to, amountxDAI);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(bytes memory path0, bytes memory path1) internal view returns (address pairOut, uint256 amountBaseOut, uint256 amountQuoteOut) {
        SwapParams memory spIn = abi.decode(path0, (SwapParams));
        SwapParams memory spOut = abi.decode(path1, (SwapParams));
        pairOut = DAOfiV1Library.pairFor(factory,  spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee);
        IDAOfiV1Pair pair = IDAOfiV1Pair(pairOut);
        (uint reserveBase, uint reserveQuote,) = pair.getReserves();
        CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
        if (params.baseToken == spOut.token) {
            uint256 amountInput = IERC20(spIn.token).balanceOf(address(pair)).sub(reserveQuote).mul(1000 - params.fee) / 1000;
            amountBaseOut = pair.getBaseOut(amountInput);
        } else {
            uint256 amountInput = IERC20(spIn.token).balanceOf(address(pair)).sub(reserveBase).mul(1000 - params.fee) / 1000;
            amountQuoteOut = pair.getQuoteOut(amountInput);
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        bytes[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) {
        SwapParams memory sp0 = abi.decode(path[0], (SwapParams));
        SwapParams memory sp1 = abi.decode(path[1], (SwapParams));
        TransferHelper.safeTransferFrom(
            sp0.token, msg.sender,
            DAOfiV1Library.pairFor(factory, sp0.token, sp1.token, sp0.m, sp0.n, sp0.fee),
            amountIn
        );
        SwapParams memory spFinal = abi.decode(path[path.length - 1], (SwapParams));
        uint balanceBefore = IERC20(spFinal.token).balanceOf(to);
        for (uint i; i < path.length - 1; i++) {
            (address pairOut, uint256 amountBaseOut, uint256 amountQuoteOut) = _swap(path[i], path[i + 1]);
            SwapParams memory spOut = abi.decode(path[i + 1], (SwapParams));
            address _to = to;
            if (i < path.length - 2) {
                SwapParams memory spNext = abi.decode(path[i + 2], (SwapParams));
                _to = DAOfiV1Library.pairFor(factory, spOut.token, spNext.token, spOut.m, spOut.n, spOut.fee);
            }
            IDAOfiV1Pair(pairOut).swap(
                amountBaseOut,
                amountQuoteOut,
                _to,
                new bytes(0)
            );
        }
        require(
            IERC20(spFinal.token).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactxDAIForTokens(
        uint amountOutMin,
        bytes[] calldata path,
        address to,
        uint deadline
    ) external override payable ensure(deadline) {
        SwapParams memory sp0 = abi.decode(path[0], (SwapParams));
        require(sp0.token == WxDAI, 'DAOfiV1Router: INVALID_PATH');
        SwapParams memory sp1 = abi.decode(path[1], (SwapParams));
        IWxDAI(WxDAI).deposit{value: msg.value}();
        assert(IWxDAI(WxDAI).transfer(
            DAOfiV1Library.pairFor(factory, sp0.token, sp1.token, sp0.m, sp0.n, sp0.fee),
            msg.value
        ));
        SwapParams memory spFinal = abi.decode(path[path.length - 1], (SwapParams));
        uint balanceBefore = IERC20(spFinal.token).balanceOf(to);
        for (uint i; i < path.length - 1; i++) {
            (address pairOut, uint256 amountBaseOut, uint256 amountQuoteOut) = _swap(path[i], path[i + 1]);
            SwapParams memory spOut = abi.decode(path[i + 1], (SwapParams));
            address _to = to;
            if (i < path.length - 2) {
                SwapParams memory spNext = abi.decode(path[i + 2], (SwapParams));
                _to = DAOfiV1Library.pairFor(factory, spOut.token, spNext.token, spOut.m, spOut.n, spOut.fee);
            }
            IDAOfiV1Pair(pairOut).swap(
                amountBaseOut,
                amountQuoteOut,
                _to,
                new bytes(0)
            );
        }
        require(
            IERC20(spFinal.token).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForxDAI(
        uint amountIn,
        uint amountOutMin,
        bytes[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) {
        SwapParams memory spFinal = abi.decode(path[path.length - 1], (SwapParams));
        require(spFinal.token == WxDAI, 'DAOfiV1Router: INVALID_PATH');
        SwapParams memory sp0 = abi.decode(path[0], (SwapParams));
        SwapParams memory sp1 = abi.decode(path[1], (SwapParams));
        TransferHelper.safeTransferFrom(
            sp0.token,
            msg.sender,
            DAOfiV1Library.pairFor(factory, sp0.token, sp1.token, sp0.m, sp0.n, sp0.fee),
            amountIn
        );
        for (uint i; i < path.length - 1; i++) {
            (address pairOut, uint256 amountBaseOut, uint256 amountQuoteOut) = _swap(path[i], path[i + 1]);
            SwapParams memory spOut = abi.decode(path[i + 1], (SwapParams));
            address _to = address(this);
            if (i < path.length - 2) {
                SwapParams memory spNext = abi.decode(path[i + 2], (SwapParams));
                _to = DAOfiV1Library.pairFor(factory, spOut.token, spNext.token, spOut.m, spOut.n, spOut.fee);
            }
            IDAOfiV1Pair(pairOut).swap(
                amountBaseOut,
                amountQuoteOut,
                _to,
                new bytes(0)
            );
        }
        uint amountOut = IERC20(WxDAI).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWxDAI(WxDAI).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    function priceQuote(uint256 amountBaseIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view override returns (uint256 amountQuoteOut)
    {
        amountQuoteOut = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getQuoteOut(amountBaseIn);
    }

    function priceBase(uint256 amountQuoteIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        external view override returns (uint256 amountBaseOut)
    {
        amountBaseOut = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getBaseOut(amountQuoteIn);
    }

    function getBaseOut(uint256 amountQuoteIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountBaseOut)
    {
        amountQuoteIn = amountQuoteIn.mul(1000 - fee) / 1000;
        amountBaseOut = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getBaseOut(amountQuoteIn);
    }

    function getQuoteOut(uint256 amountBaseIn, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountQuoteOut)
    {
        amountBaseIn = amountBaseIn.mul(1000 - fee) / 1000;
        amountQuoteOut = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getQuoteOut(amountBaseIn);
    }

    function getBaseIn(uint256 amountQuoteOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountBaseIn)
    {
        amountQuoteOut = amountQuoteOut.mul(1000 + fee) / 1000;
        amountBaseIn = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getBaseIn(amountQuoteOut);
    }

    function getQuoteIn(uint256 amountBaseOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountQuoteIn)
    {
        amountBaseOut = amountBaseOut.mul(1000 + fee) / 1000;
        amountQuoteIn = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getQuoteIn(amountBaseOut);
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
            IDAOfiV1Pair pair = IDAOfiV1Pair(
                DAOfiV1Library.pairFor(factory, spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee)
            );
            CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
            if (params.baseToken == spOut.token) {
                amounts[i + 1] = pair.getBaseOut(amounts[i].mul(1000 - params.fee) / 1000);
            } else {
                amounts[i + 1] = pair.getQuoteOut(amounts[i].mul(1000 - params.fee) / 1000);
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
            IDAOfiV1Pair pair = IDAOfiV1Pair(
                DAOfiV1Library.pairFor(factory, spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee)
            );
            CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
            if (params.baseToken == spOut.token) {
                amounts[i - 1] = pair.getQuoteIn(amounts[i].mul(1000 + params.fee) / 1000);
            } else {
                amounts[i - 1] = pair.getBaseIn(amounts[i].mul(1000 + params.fee) / 1000);
            }
        }
    }
}
