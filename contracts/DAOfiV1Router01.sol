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
