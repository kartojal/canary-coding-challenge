// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
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

    error EnforcedPause();

    function testDeposit_alpha_1week() public {
        uint256 amount = 10 ether;
        uint256 expectedShares = alphaStk_1week.convertToShares(amount);

        vm.startPrank(alice);

        tokenAlpha.approve(address(stakePool), amount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(tokenAlpha), address(alphaStk_1week), alice, BondType.OneWeek, amount, expectedShares);

        uint256 shares = stakePool.deposit(address(tokenAlpha), amount, BondType.OneWeek);
        assertEq(shares, expectedShares);
    }

    function testDeposit_alpha_4week() public {
        uint256 amount = 10 ether;
        uint256 expectedShares = alphaStk_4week.convertToShares(amount);

        vm.startPrank(alice);

        tokenAlpha.approve(address(stakePool), amount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(tokenAlpha), address(alphaStk_4week), alice, BondType.FourWeeks, amount, expectedShares);

        uint256 shares = stakePool.deposit(address(tokenAlpha), amount, BondType.FourWeeks);
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
            address(tokenAlpha), address(alphaStk_1week), alice, BondType.OneWeek, 1, expectedClaimAmount, shares
        );

        // Perform action
        uint256 tokenId = stakePool.requestWithdraw(address(alphaStk_1week), shares);

        // Assertions
        assertEq(tokenId, 1);
        assertEq(alphaStk_1week.balanceOf(alice), aliceSharesBeforeAction - 10 ether);
        assertEq(claimNFT.ownerOf(1), alice);
        assertEq(claimNFT.balanceOf(alice), 1);
        // Check NFT attributes
        (address token, uint256 creationTimestamp, uint256 amount, BondType bondType) =
            claimNFT.tokenAttributes(tokenId);
        assertEq(token, address(tokenAlpha));
        assertEq(creationTimestamp, block.timestamp);
        assertEq(amount, expectedClaimAmount);
        assertTrue(bondType == BondType.OneWeek);
        assertTrue(bytes(claimNFT.tokenURI(1)).length > 0);
    }

    function testClaim_10_alpha_1week_zero_yield() public {
        testRequestWithdraw_10_alpha_1week_zero_yield();

        uint256 aliceBalanceBeforeClaim = tokenAlpha.balanceOf(alice);
        (,, uint256 amount, BondType bondType) = claimNFT.tokenAttributes(1);
        assertTrue(bondType == BondType.OneWeek);
        assertEq(claimNFT.balanceOf(alice), 1);

        vm.warp(block.timestamp + 1 weeks);
        // Perform action
        stakePool.claim(1);

        uint256 aliceBalanceAfterClaim = tokenAlpha.balanceOf(alice);
        assertGt(aliceBalanceAfterClaim, aliceBalanceBeforeClaim);
        assertEq(aliceBalanceAfterClaim, aliceBalanceBeforeClaim + amount);
        assertEq(claimNFT.balanceOf(alice), 0);
        vm.expectRevert("NOT_MINTED");
        claimNFT.ownerOf(1);
    }

    function testClaim_10_alpha_1week_oneYear_yield() public {
        test_requestWithdraw_10_alpha_1_week_oneYear_yield();

        uint256 aliceBalanceBeforeClaim = tokenAlpha.balanceOf(alice);
        (,, uint256 amount, BondType bondType) = claimNFT.tokenAttributes(1);
        assertTrue(bondType == BondType.OneWeek);
        assertEq(claimNFT.balanceOf(alice), 1);

        vm.warp(block.timestamp + 1 weeks);
        // Perform action
        stakePool.claim(1);

        uint256 aliceBalanceAfterClaim = tokenAlpha.balanceOf(alice);
        assertGt(aliceBalanceAfterClaim, aliceBalanceBeforeClaim);
        assertEq(aliceBalanceAfterClaim, aliceBalanceBeforeClaim + amount);
        assertEq(claimNFT.balanceOf(alice), 0);
        vm.expectRevert("NOT_MINTED");
        claimNFT.ownerOf(1);
    }

    function testClaim_10_alpha_4week_oneYear_yield() public {
        test_requestWithdraw_10_alpha_4_week_oneYear_yield();

        uint256 aliceBalanceBeforeClaim = tokenAlpha.balanceOf(alice);
        (,, uint256 amount, BondType bondType) = claimNFT.tokenAttributes(1);
        assertTrue(bondType == BondType.FourWeeks);
        assertEq(claimNFT.balanceOf(alice), 1);

        vm.warp(block.timestamp + 4 weeks);
        // Perform action
        stakePool.claim(1);

        uint256 aliceBalanceAfterClaim = tokenAlpha.balanceOf(alice);
        assertGt(aliceBalanceAfterClaim, aliceBalanceBeforeClaim);
        assertEq(aliceBalanceAfterClaim, aliceBalanceBeforeClaim + amount);
        assertEq(claimNFT.balanceOf(alice), 0);
        vm.expectRevert("NOT_MINTED");
        claimNFT.ownerOf(1);
    }

    function testClaim_10_alpha_4week_oneYear_yield_bondNotMature() public {
        test_requestWithdraw_10_alpha_4_week_oneYear_yield();

        (,,, BondType bondType) = claimNFT.tokenAttributes(1);
        assertTrue(bondType == BondType.FourWeeks);
        assertEq(claimNFT.balanceOf(alice), 1);

        vm.warp(block.timestamp + 2 weeks);
        vm.expectRevert(ICanaryStakePoolErrors.BondNotMature.selector);
        stakePool.claim(1);
    }

    function testDeposit_expectReverts_UnsupportedBondType() public {
        vm.expectRevert(ICanaryStakePoolErrors.UnsupportedBondType.selector);
        stakePool.deposit(address(tokenAlpha), 1 ether, BondType.Matured);
    }

    function testClaim_10_alpha_1week_oneYear_yield_bondNotMature() public {
        test_requestWithdraw_10_alpha_1_week_oneYear_yield();

        (,,, BondType bondType) = claimNFT.tokenAttributes(1);
        assertTrue(bondType == BondType.OneWeek);
        assertEq(claimNFT.balanceOf(alice), 1);

        vm.warp(block.timestamp + 4 days);
        vm.expectRevert(ICanaryStakePoolErrors.BondNotMature.selector);
        stakePool.claim(1);
    }

    function test_adminYieldDeposit_alpha_1_week_oneYear_yield() public {
        vm.warp(block.timestamp + 365 days);

        (uint256 missingYield,) = stakePool.calculatePendingYield(address(alphaStk_1week));

        assertGt(missingYield, 0);

        tokenAlpha.mint(admin, missingYield);

        vm.startPrank(admin);
        tokenAlpha.approve(address(stakePool), missingYield);
        stakePool.adminYieldDeposit(address(alphaStk_1week));
    }

    function test_adminYieldDeposit_alpha_4_week_oneYear_yield() public {
        vm.warp(block.timestamp + 365 days);

        (uint256 missingYield,) = stakePool.calculatePendingYield(address(alphaStk_4week));

        assertGt(missingYield, 0);

        tokenAlpha.mint(admin, missingYield);

        vm.startPrank(admin);
        tokenAlpha.approve(address(stakePool), missingYield);
        stakePool.adminYieldDeposit(address(alphaStk_4week));
    }

    function test_requestWithdraw_10_alpha_1_week_oneYear_yield() public {
        testDeposit_alpha_1week();
        test_adminYieldDeposit_alpha_1_week_oneYear_yield();

        uint256 shares = 10 ether;
        uint256 expectedClaimAmount = alphaStk_1week.previewRedeem(shares);

        console2.log("Claim amount: %e", expectedClaimAmount);
        uint256 aliceSharesBeforeAction = alphaStk_1week.balanceOf(alice);
        assertNotEq(shares, 0);

        vm.startPrank(alice);

        alphaStk_1week.approve(address(stakePool), shares);

        vm.expectEmit(true, true, true, true);
        emit WithdrawalRequest(
            address(tokenAlpha), address(alphaStk_1week), alice, BondType.OneWeek, 1, expectedClaimAmount, shares
        );

        // Perform action
        uint256 tokenId = stakePool.requestWithdraw(address(alphaStk_1week), shares);

        // Assertions
        assertEq(tokenId, 1);
        assertEq(alphaStk_1week.balanceOf(alice), aliceSharesBeforeAction - 10 ether);
        assertEq(claimNFT.ownerOf(1), alice);
        assertEq(claimNFT.balanceOf(alice), 1);
        // Check NFT attributes
        (address token, uint256 creationTimestamp, uint256 amount, BondType bondType) =
            claimNFT.tokenAttributes(tokenId);
        assertEq(token, address(tokenAlpha));
        assertEq(creationTimestamp, block.timestamp);
        assertEq(amount, expectedClaimAmount);
        assertTrue(bondType == BondType.OneWeek);
    }

    function test_requestWithdraw_10_alpha_4_week_oneYear_yield() public {
        test_adminYieldDeposit_alpha_4_week_oneYear_yield();

        uint256 shares = 10 ether;
        uint256 expectedClaimAmount = alphaStk_4week.previewRedeem(shares);

        console2.log("Claim amount: %e", expectedClaimAmount);
        uint256 aliceSharesBeforeAction = alphaStk_4week.balanceOf(alice);
        assertNotEq(shares, 0);

        vm.startPrank(alice);

        alphaStk_4week.approve(address(stakePool), shares);

        vm.expectEmit(true, true, true, true);
        emit WithdrawalRequest(
            address(tokenAlpha), address(alphaStk_4week), alice, BondType.FourWeeks, 1, expectedClaimAmount, shares
        );

        // Perform action
        uint256 tokenId = stakePool.requestWithdraw(address(alphaStk_4week), shares);

        // Assertions
        assertEq(tokenId, 1);
        assertEq(alphaStk_4week.balanceOf(alice), aliceSharesBeforeAction - 10 ether);
        assertEq(claimNFT.ownerOf(1), alice);
        assertEq(claimNFT.balanceOf(alice), 1);
        // Check NFT attributes
        (address token, uint256 creationTimestamp, uint256 amount, BondType bondType) =
            claimNFT.tokenAttributes(tokenId);
        assertEq(token, address(tokenAlpha));
        assertEq(creationTimestamp, block.timestamp);
        assertEq(amount, expectedClaimAmount);
        assertTrue(bondType == BondType.FourWeeks);
    }

    function test_whitelistTokens_true() public {
        MockERC20 tokenGamma = new MockERC20("GAMMA", 18);
        MockERC20 tokenDelta = new MockERC20("DELTA", 8);

        vm.startPrank(admin);
        stakePool.whitelistToken(address(tokenGamma), true);
        stakePool.whitelistToken(address(tokenDelta), true);

        assertEq(stakePool.tokenWhitelist(address(tokenGamma)), true);
        assertEq(stakePool.tokenWhitelist(address(tokenDelta)), true);
    }

    function test_whitelistTokens_false() public {
        test_requestWithdraw_10_alpha_1_week_oneYear_yield();
        assertEq(claimNFT.balanceOf(alice), 1);

        vm.startPrank(admin);
        stakePool.whitelistToken(address(tokenAlpha), false);

        // Ensure deposits and withdrawal requests are now unreachable due unlisted token
        vm.startPrank(alice);

        vm.expectRevert(ICanaryStakePoolErrors.TokenNotWhitelisted.selector);
        stakePool.deposit(address(tokenAlpha), 10 ether, BondType.OneWeek);

        vm.expectRevert(ICanaryStakePoolErrors.TokenNotWhitelisted.selector);
        stakePool.requestWithdraw(address(alphaStk_1week), 10 ether);

        // Due underlying tokens are in the contract after withdrawal request,
        // allow not-whitelisted claims if user already claimed and funds are waiting to be collected
        (,, uint256 amount,) = claimNFT.tokenAttributes(1);
        uint256 aliceBalanceBeforeClaim = tokenAlpha.balanceOf(alice);
        vm.warp(block.timestamp + 1 weeks);

        stakePool.claim(1);

        assertEq(claimNFT.balanceOf(alice), 0);
        assertEq(tokenAlpha.balanceOf(alice), aliceBalanceBeforeClaim + amount);
    }

    function test_claim_unauthorized() public {
        test_requestWithdraw_10_alpha_1_week_oneYear_yield();
        assertEq(claimNFT.balanceOf(alice), 1);

        vm.startPrank(bob);
        vm.expectRevert(ICanaryStakePoolErrors.UnauthorizedClaim.selector);
        stakePool.claim(1);
    }

    function test_paused() public {
        assertEq(stakePool.paused(), false);

        vm.startPrank(admin);
        stakePool.pause();
        assertEq(stakePool.paused(), true);

        // Ensure deposits, withdrawal requests, and claims are paused
        vm.expectRevert(EnforcedPause.selector);
        stakePool.deposit(address(tokenAlpha), 10 ether, BondType.OneWeek);

        vm.expectRevert(EnforcedPause.selector);
        stakePool.requestWithdraw(address(tokenAlpha), 10 ether);

        vm.expectRevert(EnforcedPause.selector);
        stakePool.claim(1);

        vm.startPrank(admin);
        stakePool.unpause();
        assertEq(stakePool.paused(), false);

        // Ensure deposits works again after unpaused
        testDeposit_alpha_1week();
    }

    function test_deployment() public {
        address[] memory initialTokensWhitelist = new address[](1);
        initialTokensWhitelist[0] = address(tokenAlpha);

        CanaryStakePool newPool = new CanaryStakePool(admin, initialTokensWhitelist);

        assertTrue(newPool.tokenWhitelist(address(tokenAlpha)));
    }

    function setUp() public {
        admin = makeAddr("admin");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        tokenAlpha = new MockERC20("ALPHA", 18);
        tokenBeta = new MockERC20("BETA", 8);

        vm.label(address(tokenAlpha), "Token ALPHA");
        vm.label(address(tokenBeta), "Token BETA");

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

        alphaStk_1week = CanaryStakeToken(stakePool.stakeTokenAddressMap(address(tokenAlpha), BondType.OneWeek));
        alphaStk_4week = CanaryStakeToken(stakePool.stakeTokenAddressMap(address(tokenAlpha), BondType.FourWeeks));
        betaStk_1week = CanaryStakeToken(stakePool.stakeTokenAddressMap(address(tokenBeta), BondType.OneWeek));
        betaStk_4week = CanaryStakeToken(stakePool.stakeTokenAddressMap(address(tokenBeta), BondType.FourWeeks));
    }
}
