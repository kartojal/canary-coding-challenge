// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Pausable} from "../utils/Pausable.sol";
import {CanaryStakeClaimNFT} from "./CanaryStakeClaimNFT.sol";
import {CanaryStakeToken} from "./CanaryStakeToken.sol";

import {IERC20} from "../interfaces/IERC20.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";
import {ICanaryStakePool, BondType, StakeBondToken} from "../interfaces/ICanaryStakePool.sol";

contract CanaryStakePool is ICanaryStakePool, Pausable, Owned {
    using SafeTransferLib for ERC20;

    mapping(address token => bool) public tokenWhitelist;
    mapping(address token => mapping(BondType => address)) stakeTokenAddress;
    mapping(address stakeToken => StakeBondToken) stakeBondToken;

    CanaryStakeClaimNFT public immutable canaryClaimNFT;

    constructor(
        address admin,
        address[] memory initialTokensWhitelist
    ) Owned(admin) {
        for (uint256 i; i < initialTokensWhitelist.length; i++) {
            tokenWhitelist[initialTokensWhitelist[i]] = true;
        }
        canaryClaimNFT = new CanaryStakeClaimNFT(
            "Canary Stake NFT",
            "C-STAKE-NFT",
            address(this)
        );
    }

    function deposit(
        address token,
        uint256 amount,
        BondType bondType
    ) external returns (uint256) {
        if (tokenWhitelist[token] != true) {
            revert TokenNotWhitelisted();
        }
        if (bondType == BondType.Matured) {
            revert UnsupportedBondType();
        }
        address stakeTokenAddress = stakeTokenAddress[token][bondType];

        if (stakeTokenAddress == address(0)) {
            stakeTokenAddress = _createBondToken(stakeToken, token, bondType);
        }

        StakeBondToken stakeToken = stakeBondToken[stakeTokenAddress];

        stakeToken.underlyingToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );

        uint256 shares = stakeToken.stakingToken.deposit(amount, msg.sender);

        emit Deposit(
            token,
            stakeTokenAddress,
            msg.sender,
            bondType,
            amount,
            shares
        );

        return shares;
    }

    function requestWithdraw(
        address stakeTokenAddress,
        uint256 shares
    ) external returns (uint256 tokenId) {
        StakeBondToken stakeToken = stakeBondToken[stakeTokenAddress];
        address underlyingToken = address(stakeToken.underlyingToken);

        if (tokenWhitelist[underlyingToken] != true) {
            revert TokenNotWhitelisted();
        }

        uint256 claimAmount = stakeToken.redeem(
            shares,
            address(this), // Redeem and retain user claimed amount until withdraw notice matures
            msg.sender
        );

        uint256 tokenId = canaryClaimNFT.safeMint(
            msg.sender,
            stakeToken,
            claimAmount
        );

        emit WithdrawalRequest(
            underlyingToken,
            stakeTokenAddress,
            msg.sender,
            stakeToken.bondType,
            tokenId,
            claimAmount,
            shares
        );

        return tokenId;
    }

    function claim(uint256 tokenId) external returns (uint256) {
        if (msg.sender != canaryClaimNFT.ownerOf(tokenId)) {
            revert UnauthorizedClaim();
        }

        (
            address token,
            uint256 creationTimestamp,
            uint256 amount,
            BondType bondType
        ) = canaryClaimNFT.tokenAttributes(tokenId);

        if (
            bondType == BondType.OneWeek &&
            (block.timestamp - creationTimestamp) < 1 weeks
        ) {
            revert BondNotMature();
        } else if (
            bondType == BondType.FourWeeks &&
            (block.timestamp - creationTimestamp) < 4 weeks
        ) {
            revert BondNotMature();
        }

        canaryClaimNFT.burn(tokenId);

        IERC20(token).transfer(msg.sender, amount);

        emit Withdrawal(token, tokenId, bondType, amount);

        return amount;
    }

    function adminYieldDeposit() external onlyOwner {}

    function pause() external onlyOwner {
        super._pause();
    }

    function unpause() external onlyOwner {
        super._unpause();
    }

    function whitelistToken(address token, bool value) external onlyOwner {
        tokenWhitelist[token] = value;

        emit TokenWhitelistUpdate(token, value);
    }

    function _createBondToken(
        StakeBondToken storage stakeBondTokenStg,
        address token,
        BondType bondType
    ) internal {
        string memory bondTypeString;
        string memory tokenName;
        string memory tokenSymbol;

        if (bondType == BondType.OneWeek) {
            bondTypeString = "1-week";
        } else if (bondType == BondType.FourWeeks) {
            bondTypeString = "4-week";
        }
        tokenName = string.concat(
            "Canary st",
            IERC20(token).symbol(),
            " ",
            bondTypeString,
            " notice"
        );
        tokenSymbol = string.concat(
            "CANARY-ST",
            IERC20(token).symbol(),
            "-",
            bondTypeString
        );

        stakeBondTokenStg.bondType = bondType;
        stakeBondTokenStg.underlyingToken = IERC20(token);
        stakeBondTokenStg.stakingToken = ICanaryStakeToken(
            new CanaryStakeToken(
                tokenName,
                tokenSymbol,
                IERC20(token).decimals(),
                address(this)
            )
        );

        emit StakeTokenDeployed(
            address(stakeBondTokenStg.stakingToken),
            token,
            bondType
        );
    }
}
