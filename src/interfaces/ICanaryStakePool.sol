// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "./IERC20.sol";
import {IERC4626} from "./IERC4626.sol";

interface ICanaryStakePoolEvents {
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
    event YieldDeposit(
        address indexed token,
        address indexed stakeToken,
        address indexed caller,
        uint256 yield,
        uint256 lastTimestamp,
        uint256 currentTimestamp
    );
}

interface ICanaryStakePoolErrors {
    error TokenNotWhitelisted();
    error BondNotMature();
    error UnsupportedBondType();
    error UnauthorizedClaim();
}

interface ICanaryStakePool is ICanaryStakePoolEvents, ICanaryStakePoolErrors {
    function deposit(
        address token,
        uint256 amount,
        BondType bondType
    ) external returns (uint256);

    function requestWithdraw(
        address stakeTokenAddress,
        uint256 shares
    ) external returns (uint256);

    function claim(uint256 tokenId) external returns (uint256);

    function adminYieldDeposit(address stakeTokenAddress) external;

    function pause() external;

    function unpause() external;

    function whitelistToken(address, bool) external;
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
    uint256 lastTimestamp;
}
