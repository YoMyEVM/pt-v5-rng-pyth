// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import { IWitnetRandomness } from "witnet/interfaces/IWitnetRandomness.sol";
import { RngWitnet } from "../../src/RngWitnet.sol";

contract RngWitnetForkTest is Test {

    IWitnetRandomness witnetRandomness;
    RngWitnet rngWitnet;

    uint256 fork;

    function setUp() public {
        fork = vm.createFork("sepolia");
        vm.selectFork(fork);
        witnetRandomness = IWitnetRandomness(0xa579563E3ee6884e3b4cdE1BBb2fF6305686A83f);
        rngWitnet = new RngWitnet(witnetRandomness);
        vm.deal(address(this), 1000e18);
    }

    function testRequestRandomNumberFromFork() external {
        (uint32 requestId, uint256 lockBlock) = rngWitnet.requestRandomNumber{value: 1e18}(1e18);
        assertEq(requestId, 1);
        assertEq(lockBlock, block.number);
    }

    receive() external payable {}
}