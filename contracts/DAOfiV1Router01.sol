// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Factory.sol';
import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Pair.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/IDAOfiV1Router01.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWxDAI.sol';
import './libraries/DAOfiV1Library.sol';
import './libraries/SafeMath.sol';

contract DAOfiV1Router01 is IDAOfiV1Router01 {
    using SafeMath for *;

    address public immutable override factory;
    address public immutable override WXDAI;

    /**
    * @dev Modifier to add timeout to specific functions.
    *
    * @param deadline the block.timestamp to check against
    */
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'DAOfiV1Router: EXPIRED');
        _;
    }

    /**
    * @dev Create the router given a factory and WXDAI contract.
    *
    * @param _factory address of the core factory
    * @param _WXDAI address of the WXDAI contract
    */
    constructor(address _factory, address _WXDAI) {
        require(_factory != address(0), 'DAOfiV1Router: INVALID FACTORY ADDRESS');
        require(_WXDAI != address(0), 'DAOfiV1Router: INVALID WXDAI ADDRESS');
        factory = _factory;
        WXDAI = _WXDAI;
    }

    /**
    * @dev Fallback to only accept WXDAI via WXDAI contract fallback.
    */
    receive() external payable {
        assert(msg.sender == WXDAI); // only accept WXDAI via fallback from the WXDAI contract
    }

    /**
    * @dev Method for adding initial liquidity to a pair.
    *
    * @param lp Liquidity params, see IDAOfiV1Router.sol for details
    * @param deadline block timestamp
    *
    * @return amountBase the initial supply of base token
    */
    function addLiquidity(
        LiquidityParams calldata lp,
        uint deadline
    ) external override ensure(deadline) returns (uint256 amountBase) {
        if (IDAOfiV1Factory(factory).getPair(
            lp.tokenBase,
            lp.tokenQuote,
            lp.slopeNumerator,
            lp.n,
            lp.fee
        ) == address(0)) {
            IDAOfiV1Factory(factory).createPair(
                address(this),
                lp.tokenBase,
                lp.tokenQuote,
                msg.sender,
                lp.slopeNumerator,
                lp.n,
                lp.fee
            );
        }
        address pair = DAOfiV1Library.pairFor(
            factory, lp.tokenBase, lp.tokenQuote, lp.slopeNumerator, lp.n, lp.fee
        );

        TransferHelper.safeTransferFrom(lp.tokenBase, msg.sender, pair, lp.amountBase);
        TransferHelper.safeTransferFrom(lp.tokenQuote, msg.sender, pair, lp.amountQuote);
        amountBase = IDAOfiV1Pair(pair).deposit(lp.to);
    }

    /**
    * @dev Method for adding initial liquidity to a pair.
    * Used only for pairs where XDAI is the quote token.
    *
    * @param lp Liquidity params, see IDAOfiV1Router.sol for details
    * @param deadline block timestamp
    *
    * @return amountBase the initial supply of base token
    */
    function addLiquidityXDAI(
        LiquidityParams calldata lp,
        uint deadline
    ) external override payable ensure(deadline) returns (uint256 amountBase) {
        if (IDAOfiV1Factory(factory).getPair(lp.tokenBase, WXDAI, lp.slopeNumerator, lp.n, lp.fee) == address(0)) {
            IDAOfiV1Factory(factory).createPair(
                address(this),
                lp.tokenBase,
                WXDAI,
                msg.sender,
                lp.slopeNumerator,
                lp.n,
                lp.fee
            );
        }
        address pair = DAOfiV1Library.pairFor(
            factory,
            lp.tokenBase,
            WXDAI,
            lp.slopeNumerator,
            lp.n,
            lp.fee
        );
        TransferHelper.safeTransferFrom(lp.tokenBase, msg.sender, pair, lp.amountBase);
        IWXDAI(WXDAI).deposit{value: lp.amountQuote}();
        assert(IWXDAI(WXDAI).transfer(pair, lp.amountQuote));
        amountBase = IDAOfiV1Pair(pair).deposit(lp.to);
        // refund dust eth, if any
        if (msg.value > lp.amountQuote) TransferHelper.safeTransferETH(msg.sender, msg.value - lp.amountQuote);
    }

    /**
    * @dev Method for removing the liquidity in a pair, effecitvely closing the pair to more trading.
    *
    * @param lp Liquidity params, see IDAOfiV1Router.sol for details
    * @param deadline block timestamp
    *
    * @return amountBase the amount of base token withdrawn
    * @return amountQuote the amount of quote token withdrawn
    */
    function removeLiquidity(
        LiquidityParams calldata lp,
        uint deadline
    ) external override ensure(deadline) returns (uint amountBase, uint amountQuote) {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(
            factory, lp.tokenBase, lp.tokenQuote, lp.slopeNumerator, lp.n, lp.fee
        ));
        require(msg.sender == pair.pairOwner(), 'DAOfiV1Router: FORBIDDEN');
        (amountBase, amountQuote) = pair.withdraw(lp.to);
    }

    /**
    * @dev Method for removing the liquidity in a pair, effecitvely closing the pair to more trading.
    * Used only for pairs where ETH is the quote token.
    *
    * @param lp Liquidity params, see IDAOfiV1Router.sol for details
    * @param deadline block timestamp
    *
    * @return amountToken the amount of base token withdrawn
    * @return amountETH the amount of quote token withdrawn
    */
    function removeLiquidityXDAI(
        LiquidityParams calldata lp,
        uint deadline
    ) external override ensure(deadline) returns (uint amountToken, uint amountETH) {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, lp.tokenBase, WXDAI, lp.slopeNumerator, lp.n, lp.fee));
        require(msg.sender == pair.pairOwner(), 'DAOfiV1Router: FORBIDDEN');
        (amountToken, amountETH) = pair.withdraw(address(this));
        assert(IERC20(lp.tokenBase).transfer(lp.to, amountToken));
        IWXDAI(WXDAI).withdraw(amountETH);
        TransferHelper.safeTransferETH(lp.to, amountETH);
    }

    /**
    * @dev Exchanges tokens in for tokens out.
    *
    * @param sp Swap params, see IDAOfiV1Router.sol for details
    * @param deadline block timestamp
    */
    function swapExactTokensForTokens(
        SwapParams calldata sp,
        uint deadline
    ) external override ensure(deadline) {
        IDAOfiV1Pair pair = IDAOfiV1Pair(
            DAOfiV1Library.pairFor(factory, sp.tokenBase, sp.tokenQuote, sp.slopeNumerator, sp.n, sp.fee)
        );
        TransferHelper.safeTransferFrom(
            sp.tokenIn,
            msg.sender, // use msg.sender since we are not using metatx in this version
            address(pair),
            sp.amountIn
        );

        uint balanceBefore = IERC20(sp.tokenOut).balanceOf(sp.to);
        {
            if (pair.baseToken() == sp.tokenOut) {
                (, uint reserveQuote) = pair.getReserves();
                (, uint pQuoteFee) = pair.getPlatformFees();
                (, uint oQuoteFee) = pair.getOwnerFees();
                uint amountQuoteIn = IERC20(sp.tokenIn).balanceOf(address(pair))
                    .sub(reserveQuote)
                    .sub(pQuoteFee)
                    .sub(oQuoteFee);

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
                (uint pBaseFee,) = pair.getPlatformFees();
                (uint oBaseFee,) = pair.getOwnerFees();
                uint amountBaseIn = IERC20(sp.tokenIn).balanceOf(address(pair))
                    .sub(reserveBase)
                    .sub(pBaseFee)
                    .sub(oBaseFee);

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

    /**
    * @dev Exchanges ETH in for tokens out. Used only for pairs where ETH is
    * the quote token.
    *
    * @param sp Swap params, see IDAOfiV1Router.sol for details
    * @param deadline block timestamp
    */
    function swapExactXDAIForTokens(
        SwapParams calldata sp,
        uint deadline
    ) external payable ensure(deadline) {
        require(sp.tokenQuote == WXDAI, 'DAOfiV1Router: INVALID TOKEN, WXDAI MUST BE QUOTE');
        require(sp.tokenIn == WXDAI, 'DAOfiV1Router: INVALID TOKEN, WXDAI MUST BE TOKEN IN');
        IDAOfiV1Pair pair = IDAOfiV1Pair(
            DAOfiV1Library.pairFor(factory, sp.tokenBase, sp.tokenQuote, sp.slopeNumerator, sp.n, sp.fee)
        );
        IWXDAI(WXDAI).deposit{value: msg.value}();
        assert(IWXDAI(WXDAI).transfer(address(pair), msg.value));
        uint balanceBefore = IERC20(sp.tokenOut).balanceOf(sp.to);
        (, uint reserveQuote) = pair.getReserves();
        (, uint pQuoteFee) = pair.getPlatformFees();
        (, uint oQuoteFee) = pair.getOwnerFees();
        uint amountQuoteIn = IWXDAI(WXDAI).balanceOf(address(pair))
            .sub(reserveQuote)
            .sub(pQuoteFee)
            .sub(oQuoteFee);
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

    /**
    * @dev Exchanges tokens in for ETH out. Used only for pairs where ETH is
    * the quote token.
    *
    * @param sp Swap params, see IDAOfiV1Router.sol for details
    * @param deadline block timestamp
    */
    function swapExactTokensForXDAI(
        SwapParams calldata sp,
        uint deadline
    ) external ensure(deadline) {
        require(sp.tokenQuote == WXDAI, 'DAOfiV1Router: INVALID TOKEN, WXDAI MUST BE QUOTE');
        require(sp.tokenOut == WXDAI, 'DAOfiV1Router: INVALID TOKEN, WXDAI MUST BE TOKEN OUT');
        IDAOfiV1Pair pair = IDAOfiV1Pair(
            DAOfiV1Library.pairFor(factory, sp.tokenBase, sp.tokenQuote, sp.slopeNumerator, sp.n, sp.fee)
        );
        TransferHelper.safeTransferFrom(
            sp.tokenIn,
            msg.sender,
            address(pair),
            sp.amountIn
        );
        uint balanceBefore = IWXDAI(sp.tokenOut).balanceOf(sp.to);
        (uint reserveBase,) = pair.getReserves();
        (uint pBaseFee,) = pair.getPlatformFees();
        (uint oBaseFee,) = pair.getOwnerFees();
        uint amountBaseIn = IERC20(sp.tokenIn).balanceOf(address(pair))
            .sub(reserveBase)
            .sub(pBaseFee)
            .sub(oBaseFee);
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
        uint amountOut = IWXDAI(WXDAI).balanceOf(address(this));
        require(
            IWXDAI(sp.tokenOut).balanceOf(address(this)).sub(balanceBefore) >= sp.amountOut,
            'DAOfiV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        IWXDAI(WXDAI).withdraw(amountOut);
        TransferHelper.safeTransferETH(sp.to, amountOut);
    }

    /**
    * @dev Get the price of 1 base token.
    *
    * @param tokenBase the pair's base token address
    * @param tokenQuote the pair's quote token address
    * @param slopeNumerator the numerator of the pair's m parameter
    * @param n the pair's n parameter
    * @param fee the pair's fee parameter
    *
    * @return price the price in quote tokens
    */
    function basePrice(address tokenBase, address tokenQuote, uint32 slopeNumerator, uint32 n, uint32 fee)
        public view override returns (uint256 price)
    {
        price = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenBase, tokenQuote, slopeNumerator, n, fee)).basePrice();
    }

    /**
    * @dev Get the price of 1 quote token.
    *
    * @param tokenBase the pair's base token address
    * @param tokenQuote the pair's quote token address
    * @param slopeNumerator the numerator of the pair's m parameter
    * @param n the pair's n parameter
    * @param fee the pair's fee parameter
    *
    * @return price the price in base tokens
    */
    function quotePrice(address tokenBase, address tokenQuote, uint32 slopeNumerator, uint32 n, uint32 fee)
        public view override returns (uint256 price)
    {
        price = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenBase, tokenQuote, slopeNumerator, n, fee)).quotePrice();
    }

    /**
    * @dev Get the amount of base tokens returned for a given amount of quote tokens, including fees.
    *
    * @param amountQuoteIn the amount of quote tokens being swapped
    * @param tokenBase the pair's base token address
    * @param tokenQuote the pair's quote token address
    * @param slopeNumerator the numerator of the pair's m parameter
    * @param n the pair's n parameter
    * @param fee the pair's fee parameter
    *
    * @return amountBaseOut the amount of base token returned
    */
    function getBaseOut(uint256 amountQuoteIn, address tokenBase, address tokenQuote, uint32 slopeNumerator, uint32 n, uint32 fee)
        public view override returns (uint256 amountBaseOut)
    {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenBase, tokenQuote, slopeNumerator, n, fee));
        amountQuoteIn = amountQuoteIn.mul(1000 - (fee + pair.PLATFORM_FEE())) / 1000;
        amountBaseOut = pair.getBaseOut(amountQuoteIn);
    }

    /**
    * @dev Get the amount of quote tokens returned for a given amount of base tokens, including fees.
    *
    * @param amountBaseIn the amount of base tokens being swapped
    * @param tokenBase the pair's base token address
    * @param tokenQuote the pair's quote token address
    * @param slopeNumerator the numerator of the pair's m parameter
    * @param n the pair's n parameter
    * @param fee the pair's fee parameter
    *
    * @return amountQuoteOut the amount of quote token returned
    */
    function getQuoteOut(uint256 amountBaseIn, address tokenBase, address tokenQuote, uint32 slopeNumerator, uint32 n, uint32 fee)
        public view override returns (uint256 amountQuoteOut)
    {
        IDAOfiV1Pair pair = IDAOfiV1Pair(DAOfiV1Library.pairFor(factory, tokenBase, tokenQuote, slopeNumerator, n, fee));
        amountBaseIn = amountBaseIn.mul(1000 - (fee + pair.PLATFORM_FEE())) / 1000;
        amountQuoteOut = pair.getQuoteOut(amountBaseIn);
    }
}
