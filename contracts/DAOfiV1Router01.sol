// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Factory.sol';
import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Pair.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import 'hardhat/console.sol';

import './interfaces/IDAOfiV1Router01.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH10.sol';
import './libraries/DAOfiV1Library.sol';
import './libraries/SafeMath.sol';

contract DAOfiV1Router01 is IDAOfiV1Router01 {
    using SafeMath for *;

    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'DAOfiV1Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept WETH via fallback from the WxDAI contract
    }

    function addLiquidity(
        LiquidityParams calldata lp,
        uint deadline
    ) external override ensure(deadline) returns (uint256 amountBase) {
        if (IDAOfiV1Factory(factory).getPair(
            lp.tokenBase,
            lp.tokenQuote,
            lp.m,
            lp.n,
            lp.fee
        ) == address(0)) {
            IDAOfiV1Factory(factory).createPair(
                address(this),
                lp.tokenBase,
                lp.tokenQuote,
                msg.sender,
                lp.m,
                lp.n,
                lp.fee
            );
        }
        address pair = DAOfiV1Library.pairFor(
            factory, lp.tokenBase, lp.tokenQuote, lp.m, lp.n, lp.fee
        );

        TransferHelper.safeTransferFrom(lp.tokenBase, lp.sender, pair, lp.amountBase);
        TransferHelper.safeTransferFrom(lp.tokenQuote, lp.sender, pair, lp.amountQuote);
        amountBase = IDAOfiV1Pair(pair).deposit(lp.to);
    }

    function addLiquidityETH(
        LiquidityParams calldata lp,
        uint deadline
    ) external override payable ensure(deadline) returns (uint256 amountBase) {
        if (IDAOfiV1Factory(factory).getPair(lp.tokenBase, WETH, lp.m, lp.n, lp.fee) == address(0)) {
            IDAOfiV1Factory(factory).createPair(
                address(this),
                lp.tokenBase,
                WETH,
                msg.sender,
                lp.m,
                lp.n,
                lp.fee
            );
        }
        address pair = DAOfiV1Library.pairFor(
            factory,
            lp.tokenBase,
            WETH,
            lp.m,
            lp.n,
            lp.fee
        );
        TransferHelper.safeTransferFrom(lp.tokenBase, msg.sender, pair, lp.amountBase);
        IWETH10(WETH).deposit{value: lp.amountQuote}();
        assert(IWETH10(WETH).transfer(pair, lp.amountQuote));
        amountBase = IDAOfiV1Pair(pair).deposit(lp.to);
        // refund dust eth, if any
        if (msg.value > lp.amountQuote) TransferHelper.safeTransferETH(msg.sender, msg.value - lp.amountQuote);
    }

    function removeLiquidity(
        LiquidityParams calldata lp,
        uint deadline
    ) external override ensure(deadline) returns (uint amountBase, uint amountQuote) {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(
            factory, lp.tokenBase, lp.tokenQuote, lp.m, lp.n, lp.fee
        ));
        require(msg.sender == pair.pairOwner(), 'DAOfiV1Router: FORBIDDEN');
        (amountBase, amountQuote) = pair.withdraw(lp.to);
    }

    function removeLiquidityETH(
        LiquidityParams calldata lp,
        uint deadline
    ) external override ensure(deadline) returns (uint amountToken, uint amountETH) {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, lp.tokenBase, WETH, lp.m, lp.n, lp.fee));
        require(msg.sender == pair.pairOwner(), 'DAOfiV1Router: FORBIDDEN');
        (amountToken, amountETH) = pair.withdraw(address(this));
        assert(IERC20(lp.tokenBase).transfer(lp.to, amountToken));
        IWETH10(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(lp.to, amountETH);
    }

    function swapExactTokensForTokens(
        SwapParams calldata sp,
        uint deadline
    ) external override ensure(deadline) {
        IDAOfiV1Pair pair = IDAOfiV1Pair(
            DAOfiV1Library.pairFor(factory, sp.tokenBase, sp.tokenQuote, sp.m, sp.n, sp.fee)
        );
        TransferHelper.safeTransferFrom(
            sp.tokenIn,
            sp.sender,
            address(pair),
            sp.amountIn
        );
        uint balanceBefore = IERC20(sp.tokenOut).balanceOf(sp.to);
        {
            if (pair.baseToken() == sp.tokenOut) {
                (, uint reserveQuote) = pair.getReserves();
                uint amountQuoteIn = IERC20(sp.tokenIn).balanceOf(address(pair)).sub(reserveQuote);
                uint amountBaseOut = getBaseOut(
                    amountQuoteIn,
                    pair.baseToken(),
                    pair.quoteToken(),
                    pair.slopeNumerator(),
                    pair.n(),
                    pair.fee()
                );
                pair.swap(
                    sp.tokenIn,
                    sp.tokenOut,
                    amountQuoteIn,
                    amountBaseOut,
                    sp.to
                );
            } else {
                (uint reserveBase,) = pair.getReserves();
                uint amountBaseIn = IERC20(sp.tokenIn).balanceOf(address(pair)).sub(reserveBase);
                uint amountQuoteOut = getQuoteOut(
                    amountBaseIn,
                    pair.baseToken(),
                    pair.quoteToken(),
                    pair.slopeNumerator(),
                    pair.n(),
                    pair.fee()
                );
                pair.swap(
                    sp.tokenIn,
                    sp.tokenOut,
                    amountBaseIn,
                    amountQuoteOut,
                    sp.to
                );
            }
        }
        require(
            IERC20(sp.tokenOut).balanceOf(sp.to).sub(balanceBefore) >= sp.amountOut,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactETHForTokens(
        SwapParams calldata sp,
        uint deadline
    ) external payable ensure(deadline) {
        require(sp.tokenQuote == WETH, 'DAOfiV1Router: INVALID TOKEN, WETH MUST BE QUOTE');
        require(sp.tokenIn == WETH, 'DAOfiV1Router: INVALID TOKEN, WETH MUST BE TOKEN IN');
        IDAOfiV1Pair pair = IDAOfiV1Pair(
            DAOfiV1Library.pairFor(factory, sp.tokenBase, sp.tokenQuote, sp.m, sp.n, sp.fee)
        );
        IWETH10(WETH).deposit{value: msg.value}();
        assert(IWETH10(WETH).transfer(address(pair), msg.value));
        uint balanceBefore = IERC20(sp.tokenOut).balanceOf(sp.to);
        (, uint reserveQuote) = pair.getReserves();
        uint amountQuoteIn = IWETH10(WETH).balanceOf(address(pair)).sub(reserveQuote);
        uint amountBaseOut = getBaseOut(
            amountQuoteIn,
            pair.baseToken(),
            pair.quoteToken(),
            pair.slopeNumerator(),
            pair.n(),
            pair.fee()
        );
        pair.swap(
            sp.tokenIn,
            sp.tokenOut,
            amountQuoteIn,
            amountBaseOut,
            sp.to
        );
        require(
            IERC20(sp.tokenOut).balanceOf(sp.to).sub(balanceBefore) >= sp.amountOut,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForETH(
        SwapParams calldata sp,
        uint deadline
    ) external ensure(deadline) {
        require(sp.tokenQuote == WETH, 'DAOfiV1Router: INVALID TOKEN, WETH MUST BE QUOTE');
        require(sp.tokenOut == WETH, 'DAOfiV1Router: INVALID TOKEN, WETH MUST BE TOKEN OUT');
        IDAOfiV1Pair pair = IDAOfiV1Pair(
            DAOfiV1Library.pairFor(factory, sp.tokenBase, sp.tokenQuote, sp.m, sp.n, sp.fee)
        );
        TransferHelper.safeTransferFrom(
            sp.tokenIn,
            sp.sender,
            address(pair),
            sp.amountIn
        );
        uint balanceBefore = IWETH10(sp.tokenOut).balanceOf(sp.to);
        (uint reserveBase,) = pair.getReserves();
        uint amountBaseIn = IERC20(sp.tokenIn).balanceOf(address(pair)).sub(reserveBase);
        uint amountQuoteOut = getQuoteOut(
            amountBaseIn,
            pair.baseToken(),
            pair.quoteToken(),
            pair.slopeNumerator(),
            pair.n(),
            pair.fee()
        );
        pair.swap(
            sp.tokenIn,
            sp.tokenOut,
            amountBaseIn,
            amountQuoteOut,
            address(this)
        );
        uint amountOut = IWETH10(WETH).balanceOf(address(this));
        require(
            IWETH10(sp.tokenOut).balanceOf(address(this)).sub(balanceBefore) >= sp.amountOut,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        IWETH10(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(sp.to, amountOut);
    }

    function basePrice(address tokenBase, address tokenQuote, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 price)
    {
        price = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenBase, tokenQuote, m, n, fee)).basePrice();
    }

    function quotePrice(address tokenBase, address tokenQuote, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 price)
    {
        price = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenBase, tokenQuote, m, n, fee)).quotePrice();
    }

    function getBaseOut(uint256 amountQuoteIn, address tokenBase, address tokenQuote, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountBaseOut)
    {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenBase, tokenQuote, m, n, fee));
        amountQuoteIn = amountQuoteIn.mul(1000 - (fee + pair.PLATFORM_FEE())) / 1000;
        amountBaseOut = pair.getBaseOut(amountQuoteIn);
    }

    function getQuoteOut(uint256 amountBaseIn, address tokenBase, address tokenQuote, uint32 m, uint32 n, uint32 fee)
        public view override returns (uint256 amountQuoteOut)
    {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenBase, tokenQuote, m, n, fee));
        amountBaseIn = amountBaseIn.mul(1000 - (fee + pair.PLATFORM_FEE())) / 1000;
        amountQuoteOut = pair.getQuoteOut(amountBaseIn);
    }
}
