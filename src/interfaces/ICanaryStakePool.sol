// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "./IERC20.sol";
import {IERC4626} from "./IERC4626.sol";

interface ICanaryStakePool {
    function deposit(address token, uint256 amount) external returns (uint256);

    function requestWithdraw(
        address token,
        uint256 amount
    ) external returns (uint256);

    function claim() external returns (uint256);

    function balanceOf() external returns (uint256);

    function adminYieldDeposit() external;

    function pause() external;

    function unpause() external;

    function whitelistToken(address, bool) external;

    /// Error codes ///
    error TokenNotWhitelisted();
    error BondNotMature();
    error UnsupportedBondType();
    error UnauthorizedClaim();

    /// Events ///
    event TokenWhitelistUpdate(address indexed token, bool indexed value);
    event StakeTokenDeployed(
        address indexed stakeToken,
        address indexed underlyingToken,
        BondType indexed bondType
    );
    event Deposit(
        address indexed token,
        address indexed stakeToken,
        address indexed from,
        BondType bondType,
        uint256 amount,
        uint256 shares
    );
    event WithdrawalRequest(
        address indexed token,
        address indexed stakeToken,
        address indexed from,
        BondType bondType,
        uint256 tokenId,
        uint256 claimAmount,
        uint256 shares
    );
    event Withdrawal(
        address indexed token,
        uint256 indexed tokenId,
        BondType bondType,
        uint256 claimAmount
    );
}

enum BondType {
    Matured,
    OneWeek,
    FourWeeks
}

struct StakeBondToken {
    BondType bondType;
    IERC20 underlyingToken;
    IERC4626 stakingToken;
}
