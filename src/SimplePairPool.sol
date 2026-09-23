//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SimplePairPool {
    using Math for uint256;
    IERC20 public immutable i_tokenA;
    IERC20 public immutable i_tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public constant SWAP_BASE_FEE = 3;
    uint256 public constant SWAP_FEE_UNIT = 1000;
    uint256 public constant SLIPPAGE_UNIT = 100;

    // total shares supply.
    uint256 public totalSupply;

    // Mapping of users account to their shares.
    mapping(address account => uint256 shares) public balanceOf;

    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB);
    event Swap(
        address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    error AmountMustBeGreaterThanZero();
    error InvalidLiquidityPair();
    error SharesMustBeGreaterThanZero();
    error NoLiquidityInPool();
    error InsufficientShares();
    error InvalidTokenForSwap();
    error InsufficientAmountOut();
    error SlippageExceedsSlippageUnit();

    constructor(address _tokenA, address _tokenB) {
        i_tokenA = IERC20(_tokenA);
        i_tokenB = IERC20(_tokenB);
    }

    function _mint(address to, uint256 shares) private {
        balanceOf[to] += shares;
        totalSupply += shares;
    }

    function _burn(address from, uint256 shares) private {
        balanceOf[from] -= shares;
        totalSupply -= shares;
    }

    function calculateShares(uint256 amountA, uint256 amountB) public view returns (uint256 shares) {
        if (totalSupply == 0) {
            shares = Math.sqrt(amountA * amountB);
        } else {
            uint256 sharesForA = amountA.mulDiv(totalSupply, reserveA, Math.Rounding.Floor);
            uint256 sharesForB = amountB.mulDiv(totalSupply, reserveB, Math.Rounding.Floor);
            shares = Math.min(sharesForA, sharesForB);
        }
    }

    function calculateLiquidityAmountB(uint256 amountA) public view returns (uint256 amountB) {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();
        amountB = reserveB.mulDiv(amountA, reserveA, Math.Rounding.Ceil);
    }

    function calculateLiquidityAmountA(uint256 amountB) public view returns (uint256 amountA) {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();
        amountA = reserveA.mulDiv(amountB, reserveB, Math.Rounding.Ceil);
    }

    function _update(uint256 _reserveA, uint256 _reserveB) private {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

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

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 shares) {
        if (amountA == 0 || amountB == 0) revert AmountMustBeGreaterThanZero();

        SafeERC20.safeTransferFrom(i_tokenA, msg.sender, address(this), amountA);
        SafeERC20.safeTransferFrom(i_tokenB, msg.sender, address(this), amountB);

        if (reserveA > 0 || reserveB > 0) {
            if (reserveB * amountA != reserveA * amountB) revert InvalidLiquidityPair();
        }

        shares = calculateShares(amountA, amountB);

        _mint(msg.sender, shares);

        _update(i_tokenA.balanceOf(address(this)), i_tokenB.balanceOf(address(this)));

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    function _getTokenAmount(uint256 shares) private view returns (uint256 amountA, uint256 amountB) {
        amountA = shares.mulDiv(reserveA, totalSupply, Math.Rounding.Floor);
        amountB = shares.mulDiv(reserveB, totalSupply, Math.Rounding.Floor);
    }

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

    function _getSwapFee(uint256 amountIn) private view returns (uint256) {
        return (amountIn * SWAP_BASE_FEE / SWAP_FEE_UNIT);
    }

    function _calculateSwapAmountOutA(uint256 amountIn) private view returns (uint256 amountOut) {
        if (reserveA == 0 || reserveB == 0) revert NoLiquidityInPool();

        uint256 feesAmount = _getSwapFee(amountIn);
        uint256 totalAmountIn = amountIn - feesAmount;

        uint256 tokenBTotal = reserveB + totalAmountIn;
        amountOut = reserveA.mulDiv(totalAmountIn, tokenBTotal, Math.Rounding.Floor);
    }

    function _calculateSwapAmountOutB(uint256 amountIn) private view returns (uint256 amountOut) {
        if (reserveA == 0 || reserveB == 0) revert NoLiquidityInPool();

        uint256 feesAmount = _getSwapFee(amountIn);
        uint256 totalAmountIn = amountIn - feesAmount;

        uint256 tokenATotal = reserveA + totalAmountIn;
        amountOut = reserveB.mulDiv(totalAmountIn, tokenATotal, Math.Rounding.Floor);
    }

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

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        returns (address tokenOut, uint256 amountOut)
    {
        if (tokenIn != address(i_tokenA) && tokenIn != address(i_tokenB)) revert InvalidTokenForSwap();
        if (amountIn == 0) revert AmountMustBeGreaterThanZero();

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

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getTotalLiquidity() external view returns (uint256) {
        return totalSupply;
    }

    function getUserLiquidity(address user) external view returns (uint256 shares, uint256 tokenA, uint256 tokenB) {
        shares = balanceOf[user];
        (tokenA, tokenB) = _getTokenAmount(shares);
    }

    function getSwapFee(uint256 amountIn) external view returns (uint256) {
        return _getSwapFee(amountIn);
    }

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
