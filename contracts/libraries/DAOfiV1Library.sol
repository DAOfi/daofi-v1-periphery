pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import '@daofi/daofi-v1-core/contracts/interfaces/IDAOfiV1Pair.sol';
import "./SafeMath.sol";

library DAOfiV1Library {
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

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB)
        internal pure returns (address token0, address token1)
    {
        require(tokenA != tokenB, 'DAOfiV1Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'DAOfiV1Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        internal pure returns (address pair)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1, m, n, fee)),
                hex'6a2dbde525d74120f78de7646d79785d9db48aaba527b33804ceb6078e4e5ed2' // init code hash
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        internal view returns (uint256, uint256)
    {
        return IDAOfiV1Pair(pairFor(factory, tokenA, tokenB, m, n, fee)).getReserves();
    }

    // get params
    function getCurveParams(address factory, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        internal view returns (bytes memory)
    {
        return IDAOfiV1Pair(pairFor(factory, tokenA, tokenB, m, n, fee)).getCurveParams();
    }

    // given some amount of base or quote, return the amount of quote or base, in and out.
    function getBaseOut(uint256 amountQuoteIn, address factory, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        internal view returns (uint256 amountBaseOut)
    {
        return IDAOfiV1Pair(pairFor(factory, tokenA, tokenB, m, n, fee)).getBaseOut(amountQuoteIn);
    }

    function getQuoteOut(uint256 amountBaseIn, address factory, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        internal view returns (uint256 amountQuoteOut)
    {
        return IDAOfiV1Pair(pairFor(factory, tokenA, tokenB, m, n, fee)).getBaseOut(amountBaseIn);
    }

    function getBaseIn(uint256 amountQuoteOut, address factory, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        internal view returns (uint256 amountBaseIn)
    {
        return IDAOfiV1Pair(pairFor(factory, tokenA, tokenB, m, n, fee)).getBaseIn(amountQuoteOut);
    }

    function getQuoteIn(uint256 amountBaseOut, address factory, address tokenA, address tokenB, uint32 m, uint32 n, uint32 fee)
        internal view returns (uint256 amountQuoteIn)
    {
        return IDAOfiV1Pair(pairFor(factory, tokenA, tokenB, m, n, fee)).getQuoteIn(amountBaseOut);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint256 amountIn, address factory, address[] memory path)
        internal view returns (uint256[] memory amounts)
    {
        // require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        // amounts = new uint256[](path.length);
        // amounts[0] = amountIn;
        // for (uint256 i; i < path.length - 1; i++) {
        //     (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
        //     amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        // }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint256 amountOut, address factory, address[] memory path)
        internal view returns (uint256[] memory amounts)
    {
        // require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        // amounts = new uint[](path.length);
        // amounts[amounts.length - 1] = amountOut;
        // for (uint i = path.length - 1; i > 0; i--) {
        //     (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
        //     amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        // }
    }
}
