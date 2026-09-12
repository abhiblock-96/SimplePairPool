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

    // total shares supply.
    uint256 public totalSupply;

    // Mapping of users account to their shares.
    mapping(address account => uint256 shares) public balanceOf;

    error AmountMustBeGreaterThanZero();
    error InvalidLiquidityPair();
    error SharesMustBeGreaterThanZero();
    error NoLiquidityInPool();
    error InsufficientShares();

    constructor(address _tokenA, address _tokenB) {
        i_tokenA = IERC20(_tokenA);
        i_tokenB = IERC20(_tokenB);
    }

    function _mint(address to, uint256 shares) internal {
        balanceOf[to] += shares;
        totalSupply += shares;
    }

    function _burn(address from, uint256 shares) internal {
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

    function calculateTokenB(uint256 amountA) public view returns (uint256 amountB) {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();
        amountB = reserveB.mulDiv(amountA, reserveA, Math.Rounding.Ceil);
    }

    function calculateTokenA(uint256 amountB) public view returns (uint256 amountA) {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();
        amountA = reserveA.mulDiv(amountB, reserveB, Math.Rounding.Ceil);
    }

    function addLiquidityForA(uint256 amountA) external {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();
        if (amountA == 0) revert AmountMustBeGreaterThanZero();

        uint256 amountB = calculateTokenB(amountA);

        SafeERC20.safeTransferFrom(i_tokenA, msg.sender, address(this), amountA);
        SafeERC20.safeTransferFrom(i_tokenB, msg.sender, address(this), amountB);

        uint256 shares = calculateShares(amountA, amountB);

        _mint(msg.sender, shares);

        reserveA += amountA;
        reserveB += amountB;
    }

    function addLiquidityForB(uint256 amountB) external {
        if (reserveA <= 0 || reserveB <= 0) revert NoLiquidityInPool();
        if (amountB == 0) revert AmountMustBeGreaterThanZero();

        uint256 amountA = calculateTokenA(amountB);

        SafeERC20.safeTransferFrom(i_tokenA, msg.sender, address(this), amountA);
        SafeERC20.safeTransferFrom(i_tokenB, msg.sender, address(this), amountB);

        uint256 shares = calculateShares(amountA, amountB);

        _mint(msg.sender, shares);

        reserveA += amountA;
        reserveB += amountB;
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

        reserveA += amountA;
        reserveB += amountB;
    }

    function removeLiquidity(uint256 shares) external returns (uint256 amountA, uint256 amountB) {
        if (shares == 0) revert SharesMustBeGreaterThanZero();
        if (shares > balanceOf[msg.sender]) revert InsufficientShares();

        amountA = shares.mulDiv(reserveA, totalSupply, Math.Rounding.Floor);
        amountB = shares.mulDiv(reserveB, totalSupply, Math.Rounding.Floor);

        _burn(msg.sender, shares);

        reserveA -= amountA;
        reserveB -= amountB;

        SafeERC20.safeTransfer(i_tokenA, msg.sender, amountA);
        SafeERC20.safeTransfer(i_tokenB, msg.sender, amountB);
    }
}
