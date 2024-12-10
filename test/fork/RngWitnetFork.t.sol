// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import { IEntropy } from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import { RngPyth } from "../../src/RngPyth.sol";

contract RngPythForkTest is Test {
    IEntropy pythEntropy;
    RngPyth rngPyth;

    uint256 fork;

    function setUp() public {
        // Create a fork of the ApeChain network. If you want a specific block number, specify it.
        // If not, you can omit the block number argument and Foundry will use the latest.
        fork = vm.createFork("apechain");
        vm.selectFork(fork);

        // Replace with the actual Pyth Entropy contract address on ApeChain if available.
        // If no known address, deploy a mock or skip this test.
        pythEntropy = IEntropy(0x36825bf3Fbdf5a29E2d5148bfe7Dcf7B5639e320); 

        rngPyth = new RngPyth(pythEntropy);

        vm.deal(address(this), 1000e18);
    }

    function testRequestRandomNumberFromFork() external {
        address defaultProvider = pythEntropy.getDefaultProvider();
        uint256 fee = pythEntropy.getFee(defaultProvider);

        (uint32 requestId, uint256 lockBlock) = rngPyth.requestRandomNumber{value: fee}(fee);
        assertEq(requestId, 1, "request id");
        assertEq(lockBlock, block.number, "block number");
        assertGt(fee, 0, "fee");
    }

    receive() external payable {}
}
