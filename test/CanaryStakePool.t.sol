// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/contracts/CanaryStakePool.sol";
import "../src/contracts/CanaryStakeToken.sol";
import "../src/contracts/CanaryStakeClaimNFT.sol";

import "../src/interfaces/IERC20.sol";
import "../src/interfaces/ICanaryStakePool.sol";

import "./utils/MockERC20.sol";

contract TestCanary is Test, ICanaryStakePoolEvents, ICanaryStakePoolErrors {
    CanaryStakePool stakePool;

    CanaryStakeToken alphaStk_1week;
    CanaryStakeToken alphaStk_4week;

    CanaryStakeToken betaStk_1week;
    CanaryStakeToken betaStk_4week;

    CanaryStakeClaimNFT claimNFT;

    MockERC20 tokenAlpha;
    MockERC20 tokenBeta;

    address admin;
    address alice;
    address bob;

    function testDeposit_alpha_1week() public {
        uint256 amount = 10 ether;
        uint256 expectedShares = alphaStk_1week.convertToShares(amount);

        vm.startPrank(alice);

        tokenAlpha.approve(address(stakePool), amount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(
            address(tokenAlpha),
            address(alphaStk_1week),
            alice,
            BondType.OneWeek,
            amount,
            expectedShares
        );

        uint256 shares = stakePool.deposit(
            address(tokenAlpha),
            amount,
            BondType.OneWeek
        );
        assertEq(shares, expectedShares);
    }

    function testDeposit_alpha_4week() public {
        uint256 amount = 10 ether;
        uint256 expectedShares = alphaStk_4week.convertToShares(amount);

        vm.startPrank(alice);

        tokenAlpha.approve(address(stakePool), amount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(
            address(tokenAlpha),
            address(alphaStk_4week),
            alice,
            BondType.FourWeeks,
            amount,
            expectedShares
        );

        uint256 shares = stakePool.deposit(
            address(tokenAlpha),
            amount,
            BondType.FourWeeks
        );
        assertEq(shares, expectedShares);
    }

    function testRequestWithdraw_10_alpha_1week_zero_yield() public {
        uint256 shares = 10 ether;
        uint256 expectedClaimAmount = alphaStk_1week.previewRedeem(shares);
        uint256 aliceSharesBeforeAction = alphaStk_1week.balanceOf(alice);
        assertNotEq(shares, 0);

        vm.startPrank(alice);

        alphaStk_1week.approve(address(stakePool), shares);

        vm.expectEmit(true, true, true, true);
        emit WithdrawalRequest(
            address(tokenAlpha),
            address(alphaStk_1week),
            alice,
            BondType.OneWeek,
            1,
            expectedClaimAmount,
            shares
        );

        // Perform action
        uint256 tokenId = stakePool.requestWithdraw(
            address(alphaStk_1week),
            shares
        );

        // Assertions
        assertEq(tokenId, 1);
        assertEq(
            alphaStk_1week.balanceOf(alice),
            aliceSharesBeforeAction - 10 ether
        );
        assertEq(claimNFT.ownerOf(1), alice);
        assertEq(claimNFT.balanceOf(alice), 1);
        // Check NFT attributes
        (
            address token,
            uint256 creationTimestamp,
            uint256 amount,
            BondType bondType
        ) = claimNFT.tokenAttributes(tokenId);
        assertEq(token, address(tokenAlpha));
        assertEq(creationTimestamp, block.timestamp);
        assertEq(amount, expectedClaimAmount);
        assertTrue(bondType == BondType.OneWeek);
    }

    function testClaim_10_alpha_1week_zero_yield() public {
        testRequestWithdraw_10_alpha_1week_zero_yield();

        uint256 aliceBalanceBeforeClaim = tokenAlpha.balanceOf(alice);
        (, , uint256 amount, BondType bondType) = claimNFT.tokenAttributes(1);
        assertTrue(bondType == BondType.OneWeek);
        assertEq(claimNFT.balanceOf(alice), 1);

        vm.warp(1 weeks + 1);
        // Perform action
        stakePool.claim(1);

        uint256 aliceBalanceAfterClaim = tokenAlpha.balanceOf(alice);
        assertGt(aliceBalanceAfterClaim, aliceBalanceBeforeClaim);
        assertEq(aliceBalanceAfterClaim, aliceBalanceBeforeClaim + amount);
        assertEq(claimNFT.balanceOf(alice), 0);
        vm.expectRevert("NOT_MINTED");
        claimNFT.ownerOf(1);
    }

    function test_adminYieldDeposit_alpha_1_week_oneYear_yield() public {
        vm.warp(365 days);

        (uint256 missingYield, ) = stakePool.calculatePendingYield(
            address(alphaStk_1week)
        );

        assertGt(missingYield, 0);

        tokenAlpha.mint(admin, missingYield);

        vm.startPrank(admin);
        tokenAlpha.approve(address(stakePool), missingYield);
        stakePool.adminYieldDeposit(address(alphaStk_1week));
    }

    function test_requestWithdraw_10_alpha_1_week_oneYear_yield() public {
        testDeposit_alpha_1week();
        test_adminYieldDeposit_alpha_1_week_oneYear_yield();
        uint256 shares = 10 ether;
        uint256 expectedClaimAmount = alphaStk_1week.previewRedeem(shares);
        uint256 aliceSharesBeforeAction = alphaStk_1week.balanceOf(alice);
        assertNotEq(shares, 0);

        vm.startPrank(alice);

        alphaStk_1week.approve(address(stakePool), shares);

        vm.expectEmit(true, true, true, true);
        emit WithdrawalRequest(
            address(tokenAlpha),
            address(alphaStk_1week),
            alice,
            BondType.OneWeek,
            1,
            expectedClaimAmount,
            shares
        );

        // Perform action
        uint256 tokenId = stakePool.requestWithdraw(
            address(alphaStk_1week),
            shares
        );

        // Assertions
        assertEq(tokenId, 1);
        assertEq(
            alphaStk_1week.balanceOf(alice),
            aliceSharesBeforeAction - 10 ether
        );
        assertEq(claimNFT.ownerOf(1), alice);
        assertEq(claimNFT.balanceOf(alice), 1);
        // Check NFT attributes
        (
            address token,
            uint256 creationTimestamp,
            uint256 amount,
            BondType bondType
        ) = claimNFT.tokenAttributes(tokenId);
        assertEq(token, address(tokenAlpha));
        assertEq(creationTimestamp, block.timestamp);
        assertEq(amount, expectedClaimAmount);
        assertTrue(bondType == BondType.OneWeek);
    }

    function setUp() public {
        admin = makeAddr("admin");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        tokenAlpha = new MockERC20("ALPHA", 18);
        tokenBeta = new MockERC20("BETA", 8);

        tokenAlpha.mint(alice, 2010 ether);
        tokenAlpha.mint(bob, 2010 ether);
        tokenBeta.mint(alice, 2010 ether);
        tokenBeta.mint(bob, 2010 ether);

        address[] memory initialTokensWhitelist = new address[](2);
        initialTokensWhitelist[0] = address(tokenAlpha);
        initialTokensWhitelist[1] = address(tokenBeta);

        stakePool = new CanaryStakePool(admin, initialTokensWhitelist);
        claimNFT = stakePool.canaryClaimNFT();

        // approve stake pool to transfer tokens
        vm.startPrank(alice);
        tokenAlpha.approve(address(stakePool), 2000 ether);
        tokenBeta.approve(address(stakePool), 2000 ether);
        vm.startPrank(bob);
        tokenAlpha.approve(address(stakePool), 2000 ether);
        tokenBeta.approve(address(stakePool), 2000 ether);

        // deposits to deploy stake tokens
        vm.startPrank(alice);
        stakePool.deposit(address(tokenAlpha), 1000 ether, BondType.OneWeek);
        stakePool.deposit(address(tokenAlpha), 1000 ether, BondType.FourWeeks);
        vm.startPrank(bob);
        stakePool.deposit(address(tokenBeta), 1000 ether, BondType.OneWeek);
        stakePool.deposit(address(tokenBeta), 1000 ether, BondType.FourWeeks);

        alphaStk_1week = CanaryStakeToken(
            stakePool.stakeTokenAddressMap(
                address(tokenAlpha),
                BondType.OneWeek
            )
        );
        alphaStk_4week = CanaryStakeToken(
            stakePool.stakeTokenAddressMap(
                address(tokenAlpha),
                BondType.FourWeeks
            )
        );
        betaStk_1week = CanaryStakeToken(
            stakePool.stakeTokenAddressMap(address(tokenBeta), BondType.OneWeek)
        );
        betaStk_4week = CanaryStakeToken(
            stakePool.stakeTokenAddressMap(
                address(tokenBeta),
                BondType.FourWeeks
            )
        );
    }
}
