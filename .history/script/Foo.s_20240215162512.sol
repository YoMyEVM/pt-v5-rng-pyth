// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Script } from "forge-std/Script.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract FooScript is Script {

    function run() public {
        vm.startBroadcast();
        
        vm.stopBroadcast();
    }
}
