// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICanaryStakePool} from "../interfaces/ICanaryStakePool.sol";

contract CanaryStakePool is ICanaryStakePool {
    function deposit() external returns (uint256);

    function requestWithdraw() external returns (bool);

    function claim() external returns (uint256);

    function balanceOf() external returns (uint256);

    function adminYieldDeposit() external;

    function pause() external;

    function unpause() external;
}
