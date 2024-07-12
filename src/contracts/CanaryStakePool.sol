// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Pausable} from "../utils/Pausable.sol";
import {CanaryStakeClaimNFT} from "./CanaryStakeClaimNFT.sol";
import {CanaryStakeToken} from "./CanaryStakeToken.sol";

import {IERC4626} from "../interfaces/IERC4626.sol";
import {ICanaryStakePool, BondType, StakeBondToken} from "../interfaces/ICanaryStakePool.sol";

/// @title CanaryStakePool
/// @notice See the documentation in README.md at root of repository
contract CanaryStakePool is ICanaryStakePool, Pausable, Owned {
    using SafeTransferLib for ERC20;

    mapping(address token => bool) public tokenWhitelist;
    mapping(address token => mapping(BondType => address))
        public stakeTokenAddressMap;
    mapping(address stakeToken => StakeBondToken) public stakeBondToken;

    CanaryStakeClaimNFT public immutable canaryClaimNFT;

    uint256 public constant APY_BPS = 500; // 5,00%
    uint256 public constant SECONDS_IN_A_YEAR = 365 * 24 * 60 * 60;

    /// @dev Initializes a list of whitelisted tokens in CanaryStakePool and deploys CanaryStakeClaimNFT
    /// @param admin The address of the admin of the contract
    /// @param initialTokensWhitelist The list of tokens to be whitelisted
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

    /// @notice Deposits a whitelisted token from user (msg.sender) and mints the corresponding stake token
    /// @param token The address of the token to be deposited
    /// @param amount The amount of token to be deposited
    /// @param bondType The type of bond notice to be deposited (1-week or 4-week)
    function deposit(
        address token,
        uint256 amount,
        BondType bondType
    ) external whenNotPaused returns (uint256) {
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

        stakeToken.underlyingToken.safeTransferFrom(
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

    /// @notice Requests the withdrawal from the staked token, mints a claim NFT and stops interests for the user.
    /// @param stakeTokenAddress The address of the stake token to request the withdrawal
    /// @param shares The amount of shares to be withdrawn
    function requestWithdraw(
        address stakeTokenAddress,
        uint256 shares
    ) external whenNotPaused returns (uint256) {
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

    /// @notice Claims the user stake and burns the Claim NFT, can only be called once bond matures
    /// @param tokenId The ID of the Claim NFT to be claimed
    function claim(uint256 tokenId) external whenNotPaused returns (uint256) {
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

        ERC20(token).transfer(msg.sender, amount);

        emit Withdrawal(token, tokenId, bondType, amount);

        return amount;
    }

    /// @notice Deposit the pending yield for the underlying of a staking token
    /// @dev Can be called anytime by the owner: weekly, daily, monthly, etc.
    /// @param stakeTokenAddress The address of the stake token to deposit the yield
    function adminYieldDeposit(
        address stakeTokenAddress
    ) external whenNotPaused onlyOwner {
        (uint256 yield, uint256 lastTimestamp) = calculatePendingYield(
            stakeTokenAddress
        );
        StakeBondToken storage stakeToken = stakeBondToken[stakeTokenAddress];

        if (yield > 0) {
            // Transfer the calculated yield to the staking token contract
            stakeToken.underlyingToken.safeTransferFrom(
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

    /// @notice Pauses deposits, withdrawals and claims in CanaryStakePool
    /// @dev Can only be called by the owner (multisig, dao executor, timelock, etc.)
    function pause() external onlyOwner {
        super._pause();
    }

    /// @notice Unpauses deposits, withdrawals and claims in CanaryStakePool
    /// @dev Can only be called by the owner (multisig, dao executor, timelock, etc.)
    function unpause() external onlyOwner {
        super._unpause();
    }

    /// @notice Pauses deposits, withdrawals and claims in CanaryStakePool
    /// @dev Can only be called by the owner (multisig, dao executor, timelock, etc.)
    function whitelistToken(address token, bool value) external onlyOwner {
        tokenWhitelist[token] = value;

        emit TokenWhitelistUpdate(token, value);
    }

    /// @notice Calculates the pending yield for the underlying of a staking token
    /// @param stakeTokenAddress The address of the stake token to deposit the yield
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

    /// @notice Handles the creation of a bond/staking token contract. CanaryStakePool is a factory of ERC4626 token vaults.
    /// @param token The address of the token to be staked
    /// @param bondType The type of bond notice to be created (1-week or 4-week)
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
            ERC20(token).symbol(),
            " ",
            bondTypeString,
            " notice"
        );
        tokenSymbol = string.concat(
            "CANARY-ST",
            ERC20(token).symbol(),
            "-",
            bondTypeString
        );

        IERC4626 canaryStakeToken = IERC4626(
            address(
                new CanaryStakeToken(
                    token,
                    tokenName,
                    tokenSymbol,
                    ERC20(token).decimals(),
                    address(this)
                )
            )
        );
        ERC20(token).approve(address(canaryStakeToken), type(uint256).max);

        StakeBondToken storage stakeBondTokenStg = stakeBondToken[
            address(canaryStakeToken)
        ];

        stakeBondTokenStg.bondType = bondType;
        stakeBondTokenStg.underlyingToken = ERC20(token);
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
}
