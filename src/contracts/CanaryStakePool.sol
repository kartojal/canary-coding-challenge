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
    using SafeTransferLib for IERC20;

    mapping(address token => bool) public tokenWhitelist;
    mapping(address token => mapping(BondType => address))
        public stakeTokenAddressMap;
    mapping(address stakeToken => StakeBondToken) public stakeBondToken;

    CanaryStakeClaimNFT public immutable canaryClaimNFT;

    uint256 public constant APY_BPS = 500; // 5,00%
    uint256 public constant SECONDS_IN_A_YEAR = 365 * 24 * 60 * 60;

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
        address stakeTokenAddress = stakeTokenAddressMap[token][bondType];

        if (stakeTokenAddress == address(0)) {
            stakeTokenAddress = _createBondToken(token, bondType);
        }

        StakeBondToken memory stakeToken = stakeBondToken[stakeTokenAddress];

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
    ) external returns (uint256) {
        StakeBondToken memory stakeToken = stakeBondToken[stakeTokenAddress];
        address underlyingToken = address(stakeToken.underlyingToken);

        if (tokenWhitelist[underlyingToken] != true) {
            revert TokenNotWhitelisted();
        }

        uint256 claimAmount = stakeToken.stakingToken.redeem(
            shares,
            address(this), // Redeem and retain user claimed amount until withdraw notice matures
            msg.sender
        );

        uint256 tokenId = canaryClaimNFT.safeMint(
            msg.sender,
            address(stakeToken.underlyingToken),
            claimAmount,
            stakeToken.bondType
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

    function adminYieldDeposit(address stakeTokenAddress) external onlyOwner {
        (uint256 yield, uint256 lastTimestamp) = calculatePendingYield(
            stakeTokenAddress
        );
        StakeBondToken storage stakeToken = stakeBondToken[stakeTokenAddress];

        if (yield > 0) {
            // Transfer the calculated yield to the staking token contract
            stakeToken.underlyingToken.transferFrom(
                msg.sender,
                address(stakeToken.stakingToken),
                yield
            );
            stakeToken.lastTimestamp = block.timestamp;
            emit YieldDeposit(
                address(stakeToken.underlyingToken),
                stakeTokenAddress,
                msg.sender,
                yield,
                lastTimestamp,
                block.timestamp
            );
        }
    }

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
        address token,
        BondType bondType
    ) internal returns (address) {
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

        IERC4626 canaryStakeToken = IERC4626(
            address(
                new CanaryStakeToken(
                    token,
                    tokenName,
                    tokenSymbol,
                    IERC20(token).decimals(),
                    address(this)
                )
            )
        );
        IERC20(token).approve(address(canaryStakeToken), type(uint256).max);

        StakeBondToken storage stakeBondTokenStg = stakeBondToken[
            address(canaryStakeToken)
        ];

        stakeBondTokenStg.bondType = bondType;
        stakeBondTokenStg.underlyingToken = IERC20(token);
        stakeBondTokenStg.stakingToken = canaryStakeToken;
        stakeBondTokenStg.lastTimestamp = block.timestamp;

        stakeTokenAddressMap[token][bondType] = address(canaryStakeToken);

        emit StakeTokenDeployed(
            address(stakeBondTokenStg.stakingToken),
            token,
            bondType
        );

        return address(canaryStakeToken);
    }

    function calculatePendingYield(
        address stakeTokenAddress
    ) public view returns (uint256 yield, uint256 lastTimestamp) {
        StakeBondToken memory stakeToken = stakeBondToken[stakeTokenAddress];

        uint256 currentTimestamp = block.timestamp;
        lastTimestamp = stakeToken.lastTimestamp;

        uint256 timeElapsed = currentTimestamp - lastTimestamp;
        uint256 totalSupply = stakeToken.stakingToken.totalAssets();

        yield =
            (totalSupply * APY_BPS * timeElapsed) /
            (10000 * SECONDS_IN_A_YEAR);

        return (yield, lastTimestamp);
    }
}
