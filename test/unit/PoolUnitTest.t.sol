//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BaseContract} from "test/helper/BaseContract.t.sol";
import {SimplePairPool} from "src/SimplePairPool.sol";
import {TokenA, TokenB} from "test/mocks/mockERC20.sol";

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
}
