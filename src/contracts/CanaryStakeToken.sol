// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC4626} from "solmate/tokens/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract CanaryStakeToken is ERC4626, Owned {
    using SafeTransferLib for ERC20;

    /// @dev Initializes a ERC4626 CanaryStakeToken, called by CanaryStakePool factory
    /// @param underlyingToken The address of the underlying ERC20 token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals The number of decimals of the token
    /// @param admin The address of the admin (CanaryStakePool)
    constructor(
        address underlyingToken,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address admin
    ) ERC4626(ERC20(underlyingToken), name, symbol) Owned(admin) {}

    /// @notice Deposit assets to mint shares
    function deposit(
        uint256 assets,
        address receiver
    ) public override onlyOwner returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    /// @notice Mint shares
    function mint(
        uint256 shares,
        address receiver
    ) public override onlyOwner returns (uint256 assets) {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    /// @notice Withdraw assets by burning shares
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override onlyOwner returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - shares;
            }
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /// @notice Redeem assets by burning shares
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override onlyOwner returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - shares;
            }
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /// @notice Retrieve the underlying assets supply in custody by the CanaryStakeToken ERC4626.
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
