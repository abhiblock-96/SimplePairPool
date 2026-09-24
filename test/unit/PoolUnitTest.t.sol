//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BaseContract} from "test/helper/BaseContract.t.sol";
import {SimplePairPool} from "src/SimplePairPool.sol";
import {TokenA, TokenB} from "test/mocks/mockERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract PoolUnitTest is BaseContract {
    function test_mint_MintsExpectedTokensToProvider() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);

        assertEq(dai.balanceOf(provider1), tokenAamount);
        assertEq(usdc.balanceOf(provider1), tokenBamount);
    }

    function test_allowance_ChecksTokenAllowances() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        assertEq(dai.allowance(provider1, address(pool)), 1000);
        assertEq(usdc.allowance(provider1, address(pool)), 40000);
    }

    function test_calculateShares_ReturnsExpectedSharesForInitialPool() external view {
        assertEq(pool.calculateShares(100, 20000), Math.sqrt(100 * 20000));
    }

    function test_calculateShares_ReturnsExpectedShares() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);
        _addLiquidity(provider1, 100, 20000);

        assertEq(pool.calculateShares(50, 10000), 707);
    }

    function test_calculateShares_ReturnsZeroShareIfZeroAmountProvided() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);
        _addLiquidity(provider1, 100, 20000);

        assertEq(pool.calculateShares(0, 0), 0);
    }

    function test_calculateShares_RevertIfMaxAmountProvided() external {
        _mintTokens(provider1, type(uint256).max, type(uint256).max);
        _approve(provider1, type(uint256).max, type(uint256).max);

        vm.expectRevert();
        pool.calculateShares(type(uint256).max, type(uint256).max);
    }

    function test_addLiquidity_MintsExpectedSharesToProvider() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        uint256 shares = pool.calculateShares(100, 20000);
        uint256 shareBalBefore = pool.balanceOf(provider1);

        _addLiquidity(provider1, 100, 20000);

        uint256 shareBalAfter = pool.balanceOf(provider1);

        assertEq(shareBalAfter - shareBalBefore, shares);
    }

    function test_addLiquidity_TransfersExpectedTokensToPool() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        uint256 tokenAbalBefore = dai.balanceOf(address(pool));
        uint256 tokenBbalBefore = usdc.balanceOf(address(pool));

        _addLiquidity(provider1, 100, 20000);

        uint256 tokenAbalAfter = dai.balanceOf(address(pool));
        uint256 tokenBbalAfter = usdc.balanceOf(address(pool));

        assertEq(tokenAbalAfter - tokenAbalBefore, 100);
        assertEq(tokenBbalAfter - tokenBbalBefore, 20000);
    }

    function test_addLiquidity_TransfersExpectedTokensFromProvider() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        uint256 tokenAbalBefore = dai.balanceOf(provider1);
        uint256 tokenBbalBefore = usdc.balanceOf(provider1);

        _addLiquidity(provider1, 100, 20000);

        uint256 tokenAbalAfter = dai.balanceOf(provider1);
        uint256 tokenBbalAfter = usdc.balanceOf(provider1);

        assertEq(tokenAbalBefore - tokenAbalAfter, 100);
        assertEq(tokenBbalBefore - tokenBbalAfter, 20000);
    }

    function test_addLiquidity_RevertIfZeroAmountOfTokenAProvided() external {
        vm.expectRevert(SimplePairPool.AmountMustBeGreaterThanZero.selector);
        _addLiquidity(provider1, 0, 1000);
    }

    function test_addLiquidity_RevertIfZeroAmountOfTokenBProvided() external {
        vm.expectRevert(SimplePairPool.AmountMustBeGreaterThanZero.selector);
        _addLiquidity(provider1, 10, 0);
    }

    function test_addLiquidity_RevertsIfLiquidityChangesPrice() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        vm.expectRevert(SimplePairPool.InvalidLiquidityPair.selector);
        _addLiquidity(provider1, 50, 20000);
    }

    function test_addLiquidity_ReservesContainsExactTokens() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        uint256 reserveABefore = pool.reserveA();
        uint256 reserveBBefore = pool.reserveB();

        _addLiquidity(provider1, 100, 10000);

        uint256 reserveAAfter = pool.reserveA();
        uint256 reserveBAfter = pool.reserveB();

        assertEq(reserveAAfter - reserveABefore, 100);
        assertEq(reserveBAfter - reserveBBefore, 10000);
    }

    function test_removeLiquidity_SharesAreBurnedFromProvider() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        uint256 sharesBalBefore = pool.balanceOf(provider1);

        _removeLiquidity(provider1, 500);

        uint256 sharesBalAfter = pool.balanceOf(provider1);

        assertEq(sharesBalAfter, sharesBalBefore - 500);
    }

    function test_removeLiquidity_ExpectedTokensTransferToProvider() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        uint256 tokenABalBefore = dai.balanceOf(provider1);
        uint256 tokenBBalBefore = usdc.balanceOf(provider1);

        _removeLiquidity(provider1, 500);

        uint256 tokenABalAfter = dai.balanceOf(provider1);
        uint256 tokenBBalAfter = usdc.balanceOf(provider1);

        assertEq(tokenABalAfter, tokenABalBefore + 50);
        assertEq(tokenBBalAfter, tokenBBalBefore + 5000);
    }

    function test_removeLiquidity_RevertIfZeroSharesWithdrawn() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        vm.expectRevert(SimplePairPool.SharesMustBeGreaterThanZero.selector);
        _removeLiquidity(provider1, 0);
    }

    function test_removeLiquidity_ShareTotalSupplyReducesByExactAmount() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        uint256 sharesSupplyBefore = pool.totalSupply();

        _removeLiquidity(provider1, 500);

        uint256 sharesSupplyAfter = pool.totalSupply();

        assertEq(sharesSupplyAfter, sharesSupplyBefore - 500);
    }

    function test_removeLiquidity_ReserveRemovesExactTokens() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        uint256 reserveABefore = pool.reserveA();
        uint256 reserveBBefore = pool.reserveB();

        _removeLiquidity(provider1, 500);

        uint256 reserveAAfter = pool.reserveA();
        uint256 reserveBAfter = pool.reserveB();

        assertEq(reserveABefore - reserveAAfter, 50);
        assertEq(reserveBBefore - reserveBAfter, 5000);
    }

    function test_removeLiquidity_ExpectedTokensTransferFromPool() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        uint256 poolTokenABefore = dai.balanceOf(address(pool));
        uint256 poolTokenBBefore = usdc.balanceOf(address(pool));

        _removeLiquidity(provider1, 500);

        uint256 poolTokenAAfter = dai.balanceOf(address(pool));
        uint256 poolTokenBAfter = usdc.balanceOf(address(pool));

        assertEq(poolTokenAAfter, poolTokenABefore - 50);
        assertEq(poolTokenBAfter, poolTokenBBefore - 5000);
    }

    function test_removeLiquidity_RevertIfSharesExceedTheProviderBalance() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        vm.expectRevert(SimplePairPool.InsufficientShares.selector);
        _removeLiquidity(provider1, 1500);
    }

    function test_calculateTokenA_ReturnsExpectedTokenAForLiquidity() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        assertEq(pool.calculateLiquidityAmountA(5000), 50);
    }

    function test_calculateTokenA_RevertsIfNoLiquidityInPool() external {
        vm.expectRevert(SimplePairPool.NoLiquidityInPool.selector);
        pool.calculateLiquidityAmountB(5000);
    }

    function test_calculateTokenB_ReturnsExpectedTokenBForLiquidity() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        assertEq(pool.calculateLiquidityAmountB(1), 100);
    }

    function test_calculateTokenB_RevertsIfNoLiquidityInPool() external {
        vm.expectRevert(SimplePairPool.NoLiquidityInPool.selector);
        pool.calculateLiquidityAmountB(50);
    }

    function test_addLiquidityForA_TransfersExpectedTokensToPool() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        uint256 tokenBBalBefore = usdc.balanceOf(address(pool));
        uint256 tokenABalBefore = dai.balanceOf(address(pool));
        uint256 tokenB = pool.calculateLiquidityAmountB(10);

        _addLiquidityForA(provider1, 10);

        uint256 tokenBBalAfter = usdc.balanceOf(address(pool));
        uint256 tokenABalAfter = dai.balanceOf(address(pool));

        assertEq(tokenBBalAfter, tokenBBalBefore + tokenB);
        assertEq(tokenABalAfter, tokenABalBefore + 10);
    }

    function test_addLiquidityForA_MintsExpectedSharesToProvider() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        uint256 sharesBalBefore = pool.balanceOf(provider1);
        uint256 tokenB = pool.calculateLiquidityAmountB(10);
        uint256 shares = pool.calculateShares(10, tokenB);

        _addLiquidityForA(provider1, 10);

        uint256 sharesBalAfter = pool.balanceOf(provider1);

        assertEq(sharesBalAfter, sharesBalBefore + shares);
    }

    function test_addLiquidityForA_RevertsIfZeroAmountProvided() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        vm.expectRevert(SimplePairPool.AmountMustBeGreaterThanZero.selector);
        _addLiquidityForA(provider1, 0);
    }

    function test_addLiquidityForA_RevertsIfInitialPoolIsEmpty() external {
        vm.expectRevert(SimplePairPool.NoLiquidityInPool.selector);
        _addLiquidityForA(provider1, 10);
    }

    function test_addLiquidityForB_TransfersExpectedTokensToPool() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        uint256 tokenBBalBefore = usdc.balanceOf(address(pool));
        uint256 tokenABalBefore = dai.balanceOf(address(pool));

        _addLiquidityForB(provider1, 5000);

        uint256 tokenBBalAfter = usdc.balanceOf(address(pool));
        uint256 tokenABalAfter = dai.balanceOf(address(pool));

        assertEq(tokenBBalAfter, tokenBBalBefore + 5000);
        assertEq(tokenABalAfter, tokenABalBefore + 50);
    }

    function test_addLiquidityForB_MintsExpectedSharesToProvider() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        uint256 sharesBalBefore = pool.balanceOf(provider1);

        _addLiquidityForB(provider1, 5000);

        uint256 sharesBalAfter = pool.balanceOf(provider1);

        assertEq(sharesBalAfter, sharesBalBefore + 500);
    }

    function test_addLiquidityForB_RevertsIfZeroAmountProvided() external {
        _mintTokens(provider1, tokenAamount, tokenBamount);
        _approve(provider1, 1000, 40000);

        _addLiquidity(provider1, 100, 10000);

        vm.expectRevert(SimplePairPool.AmountMustBeGreaterThanZero.selector);
        _addLiquidityForB(provider1, 0);
    }

    function test_addLiquidityForB_RevertsIfInitialPoolIsEmpty() external {
        vm.expectRevert(SimplePairPool.NoLiquidityInPool.selector);
        _addLiquidityForB(provider1, 1000);
    }

    function test_swap_TransfersExactUsdcAmountToUser() external {
        _provideLiquidityForSwap();

        _mintTokens(account1, 2e8, 5e8);
        _approve(account1, 2e8, 5e8);

        uint256 tokenABalBefore = dai.balanceOf(account1);
        uint256 tokenBBalBefore = usdc.balanceOf(account1);

        uint256 minAmountOut = pool.getMinAmountOut(1e8, address(dai), 1);

        _swap(account1, address(dai), 1e8, minAmountOut);

        uint256 tokenABalAfter = dai.balanceOf(account1);
        uint256 tokenBBalAfter = usdc.balanceOf(account1);

        assertEq(tokenABalAfter, tokenABalBefore - 1e8);
        assertEq(tokenBBalAfter, tokenBBalBefore + 149774661);
    }

    function test_swap_TransfersExactDaiAmountToUser() external {
        _provideLiquidityForSwap();

        _mintTokens(account1, 2e8, 5e8);
        _approve(account1, 2e8, 5e8);

        uint256 tokenABalBefore = dai.balanceOf(account1);
        uint256 tokenBBalBefore = usdc.balanceOf(account1);

        uint256 minAmountOut = pool.getMinAmountOut(35e5, address(usdc), 1);

        _swap(account1, address(usdc), 35e5, minAmountOut);

        uint256 tokenABalAfter = dai.balanceOf(account1);
        uint256 tokenBBalAfter = usdc.balanceOf(account1);

        assertEq(tokenABalAfter, tokenABalBefore + 1149792);
        assertEq(tokenBBalAfter, tokenBBalBefore - 35e5);
    }

    function test_swap_IncreasesConstantProductDueToSwapFee() external {
        _provideLiquidityForSwap();

        _mintTokens(account1, 2e8, 5e8);
        _approve(account1, 2e8, 5e8);

        uint256 initialReserve = pool.reserveB() * pool.reserveA();

        uint256 minAmountOut = pool.getMinAmountOut(35e5, address(usdc), 1);

        _swap(account1, address(usdc), 35e5, minAmountOut);

        uint256 finalReserve = pool.reserveB() * pool.reserveA();

        assertGt(finalReserve, initialReserve);
    }

    function test_swap_RevertsWhenInvalidTokenProvided() external {
        vm.expectRevert(SimplePairPool.InvalidTokenForSwap.selector);
        _swap(account1, address(10), 30, 0);
    }

    function test_swap_RevertsWhenZeroAmountProvided() external {
        vm.expectRevert(SimplePairPool.AmountMustBeGreaterThanZero.selector);
        _swap(account1, address(dai), 0, 0);
    }
}
