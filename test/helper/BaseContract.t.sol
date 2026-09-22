//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console} from "forge-std/Test.sol";
import {SimplePairPool} from "src/SimplePairPool.sol";
import {TokenA, TokenB} from "test/mocks/mockERC20.sol";

contract BaseContract is Test {
    SimplePairPool internal pool;
    TokenA internal dai;
    TokenB internal usdc;

    address internal admin = makeAddr("admin");
    address internal provider1 = makeAddr("provider1");
    address internal provider2 = makeAddr("provider2");
    address internal account1 = makeAddr("account1");

    /// @notice 1e9 in base unit == 1000 usdc tokens
    uint256 internal tokenAamount = 1e9;

    /// @notice 1e9 in base unit == 4000 usdc tokens
    uint256 internal tokenBamount = 4e9;

    function setUp() external {
        vm.startPrank(admin);

        dai = new TokenA();
        usdc = new TokenB();

        _grantRole();

        pool = new SimplePairPool(address(dai), address(usdc));
        vm.stopPrank();
    }

    function _grantRole() internal {
        vm.startPrank(admin);
        dai.grantRole(dai.MINTER_ROLE(), admin);
        usdc.grantRole(usdc.MINTER_ROLE(), admin);
        vm.stopPrank();
    }

    function _mintTokens(address account, uint256 amount1, uint256 amount2) internal {
        vm.startPrank(admin);
        dai.mint(account, amount1);
        usdc.mint(account, amount2);
        vm.stopPrank();
    }

    function _approve(address account, uint256 amount1, uint256 amount2) internal {
        vm.startPrank(account);
        dai.approve(address(pool), amount1);
        usdc.approve(address(pool), amount2);
        vm.stopPrank();
    }

    function _addLiquidity(address account, uint256 amount1, uint256 amount2) internal {
        vm.prank(account);
        pool.addLiquidity(amount1, amount2);
    }

    function _removeLiquidity(address account, uint256 shares) internal {
        vm.prank(account);
        pool.removeLiquidity(shares);
    }

    function _addLiquidityForA(address account, uint256 amount) internal {
        vm.prank(account);
        pool.addLiquidityForA(amount);
    }

    function _addLiquidityForB(address account, uint256 amount) internal {
        vm.prank(account);
        pool.addLiquidityForB(amount);
    }

    function _provideLiquidityForSwap() internal {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, tokenAamount, tokenBamount);

        _addLiquidity(provider1, 1e8, 3e8);
    }

    function _swap(address account, address tokenIn, uint256 amount) internal {
        vm.prank(account);
        pool.swap(tokenIn, amount);
    }
}
