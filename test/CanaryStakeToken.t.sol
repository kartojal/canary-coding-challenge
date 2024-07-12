// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/contracts/CanaryStakeToken.sol";

import "../src/interfaces/IERC20.sol";
import "../src/interfaces/ICanaryStakePool.sol";

import "./utils/MockERC20.sol";

contract TestCanaryToken is Test {
    CanaryStakeToken alphaStk;
    MockERC20 tokenAlpha;

    address admin;
    address alice;

    function testDeposit() public {
        uint256 amount = 10 ether;
        uint256 previousBalance = alphaStk.balanceOf(admin);
        uint256 previousTokenBalance = tokenAlpha.balanceOf(admin);
        uint256 expectedShares = alphaStk.convertToShares(amount);

        vm.startPrank(admin);

        tokenAlpha.approve(address(alphaStk), amount);

        uint256 shares = alphaStk.deposit(amount, admin);
        assertEq(shares, expectedShares);
        assertEq(alphaStk.balanceOf(admin), previousBalance + expectedShares);
        assertEq(tokenAlpha.balanceOf(admin), previousTokenBalance - amount);
    }

    function testMint() public {
        uint256 amount = 10 ether;
        uint256 previousBalance = alphaStk.balanceOf(admin);
        uint256 previousTokenBalance = tokenAlpha.balanceOf(admin);

        uint256 expectedShares = alphaStk.convertToShares(amount);

        vm.startPrank(admin);

        tokenAlpha.approve(address(alphaStk), amount);

        uint256 assets = alphaStk.mint(expectedShares, admin);
        assertEq(assets, amount);
        assertEq(alphaStk.balanceOf(admin), previousBalance + expectedShares);
        assertEq(tokenAlpha.balanceOf(admin), previousTokenBalance - amount);
    }

    function testRedeem() public {
        testDeposit();
        uint256 shares = 10 ether;
        uint256 expectedClaimAmount = alphaStk.previewRedeem(shares);
        uint256 adminSharesBeforeAction = alphaStk.balanceOf(admin);
        uint256 adminTokenBalanceBeforeAction = tokenAlpha.balanceOf(admin);
        assertNotEq(shares, 0);

        vm.startPrank(admin);

        alphaStk.approve(address(alphaStk), shares);

        // Perform action
        alphaStk.redeem(shares, admin, admin);

        // Assertions
        assertEq(alphaStk.balanceOf(admin), adminSharesBeforeAction - 10 ether);
        assertEq(tokenAlpha.balanceOf(admin), adminTokenBalanceBeforeAction + expectedClaimAmount);
    }

    function testWithdraw() public {
        testDeposit();
        uint256 shares = 10 ether;
        uint256 expectedClaimAmount = alphaStk.previewRedeem(shares);
        uint256 adminSharesBeforeAction = alphaStk.balanceOf(admin);
        uint256 adminTokenBalanceBeforeAction = tokenAlpha.balanceOf(admin);
        assertNotEq(shares, 0);

        vm.startPrank(admin);

        alphaStk.approve(address(alphaStk), shares);

        // Perform action
        alphaStk.withdraw(expectedClaimAmount, admin, admin);

        // Assertions
        assertEq(alphaStk.balanceOf(admin), adminSharesBeforeAction - 10 ether);
        assertEq(tokenAlpha.balanceOf(admin), adminTokenBalanceBeforeAction + expectedClaimAmount);
    }

    // This case is unreachable due CanaryStakeToken owner would be always CanaryStakePool
    function testWithdraw_with_approval() public {
        testDeposit();
        uint256 shares = 10 ether;
        uint256 expectedClaimAmount = alphaStk.previewRedeem(shares);
        uint256 adminSharesBeforeAction = alphaStk.balanceOf(admin);
        uint256 aliceBalanceBeforeAction = alphaStk.balanceOf(alice);
        assertNotEq(shares, 0);

        vm.startPrank(admin);

        alphaStk.approve(address(alice), shares);
        alphaStk.transferOwnership(alice);

        vm.startPrank(alice);
        // Perform action
        alphaStk.withdraw(expectedClaimAmount, alice, admin);

        // Assertions
        assertEq(alphaStk.balanceOf(admin), adminSharesBeforeAction - 10 ether);
        assertEq(tokenAlpha.balanceOf(alice), aliceBalanceBeforeAction + expectedClaimAmount);
    }

    function setUp() public {
        admin = makeAddr("admin");
        alice = makeAddr("alice");

        tokenAlpha = new MockERC20("ALPHA", 18);
        alphaStk = new CanaryStakeToken(address(tokenAlpha), "Alpha Staking Token", "alphaStk", 18, admin);

        tokenAlpha.mint(admin, 1000 ether);
    }
}
