// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory symbol, uint8 decimals) ERC20("MockERC20", symbol, decimals) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
