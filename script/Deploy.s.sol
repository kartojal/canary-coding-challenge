// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {CanaryStakePool} from "../src/contracts/CanaryStakePool.sol";

contract Deploy is Script {
    function run() public {
        address[] memory emptyAddressList = new address[](0);

        vm.startBroadcast();
        new CanaryStakePool(msg.sender, emptyAddressList);
        vm.stopBroadcast();
    }
}
