// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Factory.sol';
import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Pair.sol';
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import 'hardhat/console.sol';

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
        LiquidityParams calldata lp,
        uint deadline
    ) external override ensure(deadline) returns (uint256 amountBase) {
        require(IDAOfiV1Factory(factory).getPair(
            lp.tokenBase,
            lp.tokenQuote,
            lp.m,
            lp.n,
            lp.fee
        ) == address(0), 'DAOfiV1Router01: EXISTING_PAIR');
        IDAOfiV1Factory(factory).createPair(
            address(this),
            lp.tokenBase,
            lp.tokenQuote,
            lp.tokenBase,
            lp.sender,
            lp.m,
            lp.n,
            lp.fee
        );
        address pair = DAOfiV1Library.pairFor(
            factory, lp.tokenBase, lp.tokenQuote, lp.m, lp.n, lp.fee
        );
        TransferHelper.safeTransferFrom(lp.tokenBase, lp.sender, pair, lp.amountBase);
        TransferHelper.safeTransferFrom(lp.tokenQuote, lp.sender, pair, lp.amountQuote);
        amountBase = IDAOfiV1Pair(pair).deposit(lp.to);
    }

    // function addLiquidityXDAI(
    //     LiquidityParams calldata lp,
    //     address sender,
    //     address to,
    //     uint deadline
    // ) external override payable ensure(deadline) returns (uint256 amountBase) {
    //     if (IDAOfiV1Factory(factory).getPair(lp.tokenA, WxDAI, lp.m, lp.n, lp.fee) == address(0)) {
    //         IDAOfiV1Factory(factory).createPair(
    //             address(this),
    //             lp.tokenA,
    //             WxDAI,
    //             lp.tokenA,
    //             sender,
    //             lp.m,
    //             lp.n,
    //             lp.fee
    //         );
    //     }
    //     address pair = DAOfiV1Library.pairFor(
    //         factory,
    //         lp.tokenA,
    //         WxDAI,
    //         lp.m,
    //         lp.n,
    //         lp.fee
    //     );
    //     TransferHelper.safeTransferFrom(lp.tokenA, sender, pair, lp.amountA);
    //     IWxDAI(WxDAI).deposit{value: lp.amountB}();
    //     assert(IWxDAI(WxDAI).transfer(pair, lp.amountB));
    //     amountBase = IDAOfiV1Pair(pair).deposit(to);
    //     // refund dust eth, if any
    //     if (msg.value > lp.amountB) TransferHelper.safeTransferETH(sender, msg.value - lp.amountB);
    // }

    function removeLiquidity(
        LiquidityParams calldata lp,
        uint deadline
    ) external override ensure(deadline) returns (uint amountBase, uint amountQuote) {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(
            factory, lp.tokenBase, lp.tokenQuote, lp.m, lp.n, lp.fee
        ));
        CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
        require(lp.sender == params.pairOwner, 'DAOfiV1Router: FORBIDDEN');
        (amountBase, amountQuote) = pair.withdraw(lp.to);
    }

    // function removeLiquidityXDAI(
    //     LiquidityParams calldata lp,
    //     address sender,
    //     address to,
    //     uint deadline
    // ) external override ensure(deadline) returns (uint amountToken, uint amountxDAI) {
    //     IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, lp.tokenA, WxDAI, lp.m, lp.n, lp.fee));
    //     CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
    //     require(sender == params.pairOwner, 'DAOfiV1Router: FORBIDDEN');
    //     (amountToken, amountxDAI) = pair.withdraw(to);
    //     TransferHelper.safeTransfer(lp.tokenA, to, amountToken);
    //     IWxDAI(WxDAI).withdraw(amountxDAI);
    //     TransferHelper.safeTransferETH(to, amountxDAI);
    // }

    function swapExactTokensForTokens(
        SwapParams calldata sp,
        uint deadline
    ) external override ensure(deadline) {
        address pair = DAOfiV1Library.pairFor(factory, sp.tokenIn, sp.tokenOut, sp.m, sp.n, sp.fee);
        TransferHelper.safeTransferFrom(
            sp.tokenIn,
            sp.sender,
            pair,
            sp.amountIn
        );
        uint balanceBefore = IERC20(sp.tokenOut).balanceOf(sp.to);
        {
            CurveParams memory params = abi.decode(IDAOfiV1Pair(pair).getCurveParams(), (CurveParams));
            if (params.baseToken == sp.tokenOut) {
                (, uint reserveQuote,) = IDAOfiV1Pair(pair).getReserves();
                uint amountBaseOut = IDAOfiV1Pair(pair).getBaseOut(
                    IERC20(sp.tokenIn).balanceOf(address(pair)).sub(reserveQuote).mul(1000 - params.fee) / 1000
                );
                IDAOfiV1Pair(pair).swap(
                    amountBaseOut,
                    0,
                    sp.to,
                    new bytes(0)
                );
            } else {
                (uint reserveBase,,) = IDAOfiV1Pair(pair).getReserves();
                uint amountQuoteOut = IDAOfiV1Pair(pair).getQuoteOut(
                     IERC20(sp.tokenIn).balanceOf(address(pair)).sub(reserveBase).mul(1000 - params.fee) / 1000
                );
                IDAOfiV1Pair(pair).swap(
                    0,
                    amountQuoteOut,
                    sp.to,
                    new bytes(0)
                );
            }
        }
        require(
            IERC20(sp.tokenOut).balanceOf(sp.to).sub(balanceBefore) >= sp.amountOut,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    // function swapExactXDAIForTokens(
    //     uint amountOutMin,
    //     bytes[] calldata path,
    //     address to,
    //     uint deadline
    // ) external override payable ensure(deadline) {
    //     SwapParams memory sp0 = abi.decode(path[0], (SwapParams));
    //     require(sp0.token == WxDAI, 'DAOfiV1Router: INVALID_PATH');
    //     SwapParams memory sp1 = abi.decode(path[1], (SwapParams));
    //     IWxDAI(WxDAI).deposit{value: msg.value}();
    //     assert(IWxDAI(WxDAI).transfer(
    //         DAOfiV1Library.pairFor(factory, sp0.token, sp1.token, sp0.m, sp0.n, sp0.fee),
    //         msg.value
    //     ));
    //     SwapParams memory spFinal = abi.decode(path[path.length - 1], (SwapParams));
    //     uint balanceBefore = IERC20(spFinal.token).balanceOf(to);
    //     for (uint i; i < path.length - 1; i++) {
    //         (address pairOut, uint256 amountBaseOut, uint256 amountQuoteOut) = _swap(path[i], path[i + 1]);
    //         SwapParams memory spOut = abi.decode(path[i + 1], (SwapParams));
    //         address _to = to;
    //         if (i < path.length - 2) {
    //             SwapParams memory spNext = abi.decode(path[i + 2], (SwapParams));
    //             _to = DAOfiV1Library.pairFor(factory, spOut.token, spNext.token, spOut.m, spOut.n, spOut.fee);
    //         }
    //         IDAOfiV1Pair(pairOut).swap(
    //             amountBaseOut,
    //             amountQuoteOut,
    //             _to,
    //             new bytes(0)
    //         );
    //     }
    //     require(
    //         IERC20(spFinal.token).balanceOf(to).sub(balanceBefore) >= amountOutMin,
    //         'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
    //     );
    // }

    // function swapExactTokensForXDAI(
    //     uint amountIn,
    //     uint amountOutMin,
    //     bytes[] calldata path,
    //     address sender,
    //     address to,
    //     uint deadline
    // ) external override ensure(deadline) {
    //     SwapParams memory spFinal = abi.decode(path[path.length - 1], (SwapParams));
    //     require(spFinal.token == WxDAI, 'DAOfiV1Router: INVALID_PATH');
    //     SwapParams memory sp0 = abi.decode(path[0], (SwapParams));
    //     SwapParams memory sp1 = abi.decode(path[1], (SwapParams));
    //     TransferHelper.safeTransferFrom(
    //         sp0.token,
    //         sender,
    //         DAOfiV1Library.pairFor(factory, sp0.token, sp1.token, sp0.m, sp0.n, sp0.fee),
    //         amountIn
    //     );
    //     for (uint i; i < path.length - 1; i++) {
    //         (address pairOut, uint256 amountBaseOut, uint256 amountQuoteOut) = _swap(path[i], path[i + 1]);
    //         SwapParams memory spOut = abi.decode(path[i + 1], (SwapParams));
    //         address _to = address(this);
    //         if (i < path.length - 2) {
    //             SwapParams memory spNext = abi.decode(path[i + 2], (SwapParams));
    //             _to = DAOfiV1Library.pairFor(factory, spOut.token, spNext.token, spOut.m, spOut.n, spOut.fee);
    //         }
    //         IDAOfiV1Pair(pairOut).swap(
    //             amountBaseOut,
    //             amountQuoteOut,
    //             _to,
    //             new bytes(0)
    //         );
    //     }
    //     uint amountOut = IERC20(WxDAI).balanceOf(address(this));
    //     require(amountOut >= amountOutMin, 'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
    //     IWxDAI(WxDAI).withdraw(amountOut);
    //     TransferHelper.safeTransferETH(to, amountOut);
    // }

    function basePrice(address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 price)
    {
        price = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).basePrice();
    }

    function quotePrice(address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 price)
    {
        price = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).quotePrice();
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

    // function getBaseIn(uint256 amountQuoteOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
    //     public view override returns (uint256 amountBaseIn)
    // {
    //     amountQuoteOut = amountQuoteOut.mul(1000 + fee) / 1000;
    //     amountBaseIn = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getBaseIn(amountQuoteOut);
    // }

    // function getQuoteIn(uint256 amountBaseOut, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
    //     public view override returns (uint256 amountQuoteIn)
    // {
    //     amountBaseOut = amountBaseOut.mul(1000 + fee) / 1000;
    //     amountQuoteIn = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenA, tokenB, m, n, fee)).getQuoteIn(amountBaseOut);
    // }

    // function getAmountsOut(uint256 amountIn, SwapParams[] calldata path)
    //     public view override returns (uint256[] memory amounts)
    // {
    //     require(path.length >= 2, 'DAOfiV1Router: INVALID_PATH');
    //     amounts = new uint256[](path.length);
    //     amounts[0] = amountIn;
    //     for (uint256 i; i < path.length - 1; i++) {
    //         SwapParams memory spIn = abi.decode(path[i], (SwapParams));
    //         SwapParams memory spOut = abi.decode(path[i + 1], (SwapParams));
    //         IDAOfiV1Pair pair = IDAOfiV1Pair(
    //             DAOfiV1Library.pairFor(factory, spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee)
    //         );
    //         CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
    //         if (params.baseToken == spOut.token) {
    //             amounts[i + 1] = pair.getBaseOut(amounts[i].mul(1000 - params.fee) / 1000);
    //         } else {
    //             amounts[i + 1] = pair.getQuoteOut(amounts[i].mul(1000 - params.fee) / 1000);
    //         }
    //     }
    // }

    // function getAmountsIn(uint256 amountOut, SwapParams[] calldata path)
    //     public view override returns (uint256[] memory amounts)
    // {
    //     require(path.length >= 2, 'DAOfiV1Router: INVALID_PATH');
    //     amounts = new uint256[](path.length);
    //     amounts[amounts.length - 1] = amountOut;
    //     for (uint i = path.length - 1; i > 0; i--) {
    //         SwapParams memory spIn = abi.decode(path[i - 1], (SwapParams));
    //         SwapParams memory spOut = abi.decode(path[i], (SwapParams));
    //         IDAOfiV1Pair pair = IDAOfiV1Pair(
    //             DAOfiV1Library.pairFor(factory, spIn.token, spOut.token, spIn.m, spIn.n, spIn.fee)
    //         );
    //         CurveParams memory params = abi.decode(pair.getCurveParams(), (CurveParams));
    //         if (params.baseToken == spOut.token) {
    //             amounts[i - 1] = pair.getQuoteIn(amounts[i].mul(1000 + params.fee) / 1000);
    //         } else {
    //             amounts[i - 1] = pair.getBaseIn(amounts[i].mul(1000 + params.fee) / 1000);
    //         }
    //     }
    // }
}
