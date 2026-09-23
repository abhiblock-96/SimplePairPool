//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SimplePairPool
 * @author Abhishek Maurya
 * @notice A constant-product automated market maker for a pair of ERC20 tokens.
 * @dev Liquidity providers receive internal pool shares representing their
 *      proportional ownership of the pool.
 */
contract SimplePairPool {
    using Math for uint256;

    /// @notice First token supported by the pool.
    IERC20 public immutable i_tokenA;

    /// @notice Second token supported by the pool.
    IERC20 public immutable i_tokenB;

    /// @notice Current reserve of token A held by the pool.
    uint256 public reserveA;

    /// @notice Current reserve of token B held by the pool.
    uint256 public reserveB;

    /// @notice Swap fee numerator. A value of 3 with a fee unit of 1000
    ///         represents a 0.3% swap fee.
    uint256 public constant SWAP_BASE_FEE = 3;

    /// @notice Denominator used for calculating the swap fee.
    uint256 public constant SWAP_FEE_UNIT = 1000;

    /// @notice Unit used for slippage expressed as a percentage.
    ///         For example, 1 represents 1% slippage.
    uint256 public constant SLIPPAGE_UNIT = 100;

    /// @notice Total number of liquidity shares issued by the pool.
    uint256 public totalSupply;

    /// @notice Mapping of liquidity providers to their pool shares.
    mapping(address account => uint256 shares) public balanceOf;

    /**
     * @notice Emitted when liquidity is added to the pool.
     * @param user Address that supplied the liquidity.
     * @param amountA Amount of token A supplied.
     * @param amountB Amount of token B supplied.
     */
    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB);

    /**
     * @notice Emitted when liquidity is removed from the pool.
     * @param user Address that removed the liquidity.
     * @param amountA Amount of token A withdrawn.
     * @param amountB Amount of token B withdrawn.
     */
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB);

    /**
     * @notice Emitted after a successful token swap.
     * @param user Address that executed the swap.
     * @param tokenIn Address of the token supplied to the pool.
     * @param tokenOut Address of the token received from the pool.
     * @param amountIn Amount of input tokens supplied.
     * @param amountOut Amount of output tokens received.
     */
    event Swap(
        address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /// @notice Thrown when an amount is zero.
    error AmountMustBeGreaterThanZero();

    /// @notice Thrown when the supplied liquidity does not match the pool ratio.
    error InvalidLiquidityPair();

    /// @notice Thrown when the number of liquidity shares is zero.
    error SharesMustBeGreaterThanZero();

    /// @notice Thrown when an operation requires an existing liquidity pool.
    error NoLiquidityInPool();

    /// @notice Thrown when a user attempts to remove more shares than owned.
    error InsufficientShares();

    /// @notice Thrown when an unsupported token is supplied for a swap.
    error InvalidTokenForSwap();

    /// @notice Thrown when the calculated swap output is below the user's
    ///         minimum acceptable output.
    error InsufficientAmountOut();

    /// @notice Thrown when the requested slippage is greater than or equal
    ///         to the configured slippage unit.
    error SlippageExceedsSlippageUnit();

    /**
     * @notice Initializes the pool with a pair of ERC20 tokens.
     * @param _tokenA Address of token A.
     * @param _tokenB Address of token B.
     */
    constructor(address _tokenA, address _tokenB) {
        i_tokenA = IERC20(_tokenA);
        i_tokenB = IERC20(_tokenB);
    }

    /**
     * @dev Mints liquidity shares to an account.
     * @param to Address receiving the shares.
     * @param shares Number of shares to mint.
     */
    function _mint(address to, uint256 shares) private {
        balanceOf[to] += shares;
        totalSupply += shares;
    }

    /**
     * @dev Burns liquidity shares from an account.
     * @param from Address whose shares are burned.
     * @param shares Number of shares to burn.
     */
    function _burn(address from, uint256 shares) private {
        balanceOf[from] -= shares;
        totalSupply -= shares;
    }

    /**
     * @notice Calculates the number of liquidity shares received for
     *         supplying a given amount of token A and token B.
     * @param amountA Amount of token A supplied.
     * @param amountB Amount of token B supplied.
     * @return shares Number of liquidity shares that would be minted.
     */
    function calculateShares(uint256 amountA, uint256 amountB) public view returns (uint256 shares) {
        if (totalSupply == 0) {
            shares = Math.sqrt(amountA * amountB);
        } else {
            uint256 sharesForA = amountA.mulDiv(totalSupply, reserveA, Math.Rounding.Floor);

            uint256 sharesForB = amountB.mulDiv(totalSupply, reserveB, Math.Rounding.Floor);

            shares = Math.min(sharesForA, sharesForB);
        }
    }

    /**
     * @notice Calculates the amount of token B required for a given amount
     *         of token A based on the current pool ratio.
     * @param amountA Amount of token A to supply.
     * @return amountB Required amount of token B.
     */
    function calculateLiquidityAmountB(uint256 amountA) public view returns (uint256 amountB) {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();

        amountB = reserveB.mulDiv(amountA, reserveA, Math.Rounding.Ceil);
    }

    /**
     * @notice Calculates the amount of token A required for a given amount
     *         of token B based on the current pool ratio.
     * @param amountB Amount of token B to supply.
     * @return amountA Required amount of token A.
     */
    function calculateLiquidityAmountA(uint256 amountB) public view returns (uint256 amountA) {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();

        amountA = reserveA.mulDiv(amountB, reserveB, Math.Rounding.Ceil);
    }

    /**
     * @dev Updates the stored pool reserves.
     * @param _reserveA New reserve of token A.
     * @param _reserveB New reserve of token B.
     */
    function _update(uint256 _reserveA, uint256 _reserveB) private {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

    /**
     * @notice Adds liquidity using a specified amount of token A.
     * @dev The required amount of token B is calculated from the current
     *      pool ratio.
     * @param amountA Amount of token A to supply.
     */
    function addLiquidityForA(uint256 amountA) external {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();
        if (amountA == 0) revert AmountMustBeGreaterThanZero();

        uint256 amountB = calculateLiquidityAmountB(amountA);

        SafeERC20.safeTransferFrom(i_tokenA, msg.sender, address(this), amountA);

        SafeERC20.safeTransferFrom(i_tokenB, msg.sender, address(this), amountB);

        uint256 shares = calculateShares(amountA, amountB);

        _mint(msg.sender, shares);

        _update(i_tokenA.balanceOf(address(this)), i_tokenB.balanceOf(address(this)));

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    /**
     * @notice Adds liquidity using a specified amount of token B.
     * @dev The required amount of token A is calculated from the current
     *      pool ratio.
     * @param amountB Amount of token B to supply.
     */
    function addLiquidityForB(uint256 amountB) external {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();
        if (amountB == 0) revert AmountMustBeGreaterThanZero();

        uint256 amountA = calculateLiquidityAmountA(amountB);

        SafeERC20.safeTransferFrom(i_tokenA, msg.sender, address(this), amountA);

        SafeERC20.safeTransferFrom(i_tokenB, msg.sender, address(this), amountB);

        uint256 shares = calculateShares(amountA, amountB);

        _mint(msg.sender, shares);

        _update(i_tokenA.balanceOf(address(this)), i_tokenB.balanceOf(address(this)));

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    /**
     * @notice Adds liquidity by supplying both token amounts explicitly.
     * @dev For an existing pool, the supplied amounts must match the current
     *      reserve ratio.
     * @param amountA Amount of token A to supply.
     * @param amountB Amount of token B to supply.
     * @return shares Number of liquidity shares minted.
     */
    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 shares) {
        if (amountA == 0 || amountB == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        SafeERC20.safeTransferFrom(i_tokenA, msg.sender, address(this), amountA);

        SafeERC20.safeTransferFrom(i_tokenB, msg.sender, address(this), amountB);

        if (reserveA > 0 || reserveB > 0) {
            if (reserveB * amountA != reserveA * amountB) {
                revert InvalidLiquidityPair();
            }
        }

        shares = calculateShares(amountA, amountB);

        _mint(msg.sender, shares);

        _update(i_tokenA.balanceOf(address(this)), i_tokenB.balanceOf(address(this)));

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    /**
     * @dev Calculates the underlying token amounts represented by a number
     *      of liquidity shares.
     * @param shares Number of liquidity shares.
     * @return amountA Amount of token A represented by the shares.
     * @return amountB Amount of token B represented by the shares.
     */
    function _getTokenAmount(uint256 shares) private view returns (uint256 amountA, uint256 amountB) {
        amountA = shares.mulDiv(reserveA, totalSupply, Math.Rounding.Floor);

        amountB = shares.mulDiv(reserveB, totalSupply, Math.Rounding.Floor);
    }

    /**
     * @notice Removes liquidity and returns the caller's proportional share
     *         of token A and token B.
     * @param shares Number of liquidity shares to burn.
     * @return amountA Amount of token A withdrawn.
     * @return amountB Amount of token B withdrawn.
     */
    function removeLiquidity(uint256 shares) external returns (uint256 amountA, uint256 amountB) {
        if (shares == 0) revert SharesMustBeGreaterThanZero();
        if (shares > balanceOf[msg.sender]) revert InsufficientShares();

        (amountA, amountB) = _getTokenAmount(shares);

        _burn(msg.sender, shares);

        SafeERC20.safeTransfer(i_tokenA, msg.sender, amountA);
        SafeERC20.safeTransfer(i_tokenB, msg.sender, amountB);

        _update(i_tokenA.balanceOf(address(this)), i_tokenB.balanceOf(address(this)));

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    /**
     * @dev Calculates the swap fee for a given input amount.
     * @param amountIn Amount of tokens being swapped.
     * @return Fee amount charged on the input.
     */
    function _getSwapFee(uint256 amountIn) private view returns (uint256) {
        return amountIn * SWAP_BASE_FEE / SWAP_FEE_UNIT;
    }

    /**
     * @dev Calculates the amount of token B received when token A is supplied.
     * @param amountIn Amount of token A supplied.
     * @return amountOut Amount of token B received.
     */
    function _calculateSwapAmountOutA(uint256 amountIn) private view returns (uint256 amountOut) {
        if (reserveA == 0 || reserveB == 0) revert NoLiquidityInPool();

        uint256 feesAmount = _getSwapFee(amountIn);
        uint256 totalAmountIn = amountIn - feesAmount;

        uint256 tokenBTotal = reserveB + totalAmountIn;

        amountOut = reserveA.mulDiv(totalAmountIn, tokenBTotal, Math.Rounding.Floor);
    }

    /**
     * @dev Calculates the amount of token A received when token B is supplied.
     * @param amountIn Amount of token B supplied.
     * @return amountOut Amount of token A received.
     */
    function _calculateSwapAmountOutB(uint256 amountIn) private view returns (uint256 amountOut) {
        if (reserveA == 0 || reserveB == 0) revert NoLiquidityInPool();

        uint256 feesAmount = _getSwapFee(amountIn);
        uint256 totalAmountIn = amountIn - feesAmount;

        uint256 tokenATotal = reserveA + totalAmountIn;

        amountOut = reserveB.mulDiv(totalAmountIn, tokenATotal, Math.Rounding.Floor);
    }

    /**
     * @notice Calculates the minimum acceptable output amount after applying
     *         the requested slippage tolerance.
     * @param amountIn Amount of input tokens.
     * @param tokenIn Address of the input token.
     * @param slippage Maximum acceptable slippage expressed as a percentage.
     *        For example, 1 represents 1%.
     * @return minAmountOut Minimum output amount acceptable to the caller.
     */
    function getMinAmountOut(uint256 amountIn, address tokenIn, uint256 slippage)
        external
        view
        returns (uint256 minAmountOut)
    {
        if (amountIn == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        if (slippage >= SLIPPAGE_UNIT) {
            revert SlippageExceedsSlippageUnit();
        }

        if (tokenIn == address(i_tokenA)) {
            uint256 amount = _calculateSwapAmountOutB(amountIn);

            uint256 slippageAmount = amount.mulDiv(slippage, SLIPPAGE_UNIT, Math.Rounding.Floor);

            minAmountOut = amount - slippageAmount;
        } else if (tokenIn == address(i_tokenB)) {
            uint256 amount = _calculateSwapAmountOutA(amountIn);

            uint256 slippageAmount = amount.mulDiv(slippage, SLIPPAGE_UNIT, Math.Rounding.Floor);

            minAmountOut = amount - slippageAmount;
        } else {
            revert InvalidTokenForSwap();
        }
    }

    /**
     * @notice Swaps one supported token for the other token.
     * @dev The swap uses the pool's constant-product pricing formula and
     *      charges the configured swap fee. The transaction reverts when
     *      the calculated output is below minAmountOut.
     * @param tokenIn Address of the token supplied by the caller.
     * @param amountIn Amount of input tokens.
     * @param minAmountOut Minimum amount of output tokens accepted by caller.
     * @return tokenOut Address of the token received.
     * @return amountOut Amount of output tokens received.
     */
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        returns (address tokenOut, uint256 amountOut)
    {
        if (tokenIn != address(i_tokenA) && tokenIn != address(i_tokenB)) {
            revert InvalidTokenForSwap();
        }

        if (amountIn == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        if (tokenIn == address(i_tokenA)) {
            tokenOut = address(i_tokenB);
            amountOut = _calculateSwapAmountOutB(amountIn);

            if (amountOut < minAmountOut) {
                revert InsufficientAmountOut();
            }

            SafeERC20.safeTransferFrom(i_tokenA, msg.sender, address(this), amountIn);

            SafeERC20.safeTransfer(i_tokenB, msg.sender, amountOut);

            _update(i_tokenA.balanceOf(address(this)), i_tokenB.balanceOf(address(this)));

            emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        } else {
            tokenOut = address(i_tokenA);
            amountOut = _calculateSwapAmountOutA(amountIn);

            if (amountOut < minAmountOut) {
                revert InsufficientAmountOut();
            }

            SafeERC20.safeTransferFrom(i_tokenB, msg.sender, address(this), amountIn);

            SafeERC20.safeTransfer(i_tokenA, msg.sender, amountOut);

            _update(i_tokenA.balanceOf(address(this)), i_tokenB.balanceOf(address(this)));

            emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        }
    }

    /**
     * @notice Returns the current reserves of token A and token B.
     * @return reserveA_ Current reserve of token A.
     * @return reserveB_ Current reserve of token B.
     */
    function getReserves() external view returns (uint256 reserveA_, uint256 reserveB_) {
        return (reserveA, reserveB);
    }

    /**
     * @notice Returns the total liquidity shares currently issued.
     * @return Total liquidity shares.
     */
    function getTotalLiquidity() external view returns (uint256) {
        return totalSupply;
    }

    /**
     * @notice Returns a user's liquidity shares and their proportional
     *         underlying token amounts.
     * @param user Address of the liquidity provider.
     * @return shares User's liquidity shares.
     * @return tokenA User's proportional amount of token A.
     * @return tokenB User's proportional amount of token B.
     */
    function getUserLiquidity(address user) external view returns (uint256 shares, uint256 tokenA, uint256 tokenB) {
        shares = balanceOf[user];
        (tokenA, tokenB) = _getTokenAmount(shares);
    }

    /**
     * @notice Returns the swap fee charged for a given input amount.
     * @param amountIn Amount of input tokens.
     * @return Fee amount.
     */
    function getSwapFee(uint256 amountIn) external view returns (uint256) {
        return _getSwapFee(amountIn);
    }

    /**
     * @notice Returns the expected output amount for a swap using the
     *         current pool reserves.
     * @dev This value is only a quote. Reserves may change before the
     *      transaction is executed.
     * @param amountIn Amount of input tokens.
     * @param tokenIn Address of the input token.
     * @return amountOut Expected output amount.
     */
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        if (amountIn == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        if (tokenIn == address(i_tokenA)) {
            return _calculateSwapAmountOutB(amountIn);
        } else if (tokenIn == address(i_tokenB)) {
            return _calculateSwapAmountOutA(amountIn);
        } else {
            revert InvalidTokenForSwap();
        }
    }
}
