// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";
import { IWitnetRandomness } from "witnet/interfaces/IWitnetRandomness.sol";
import { RngWitnet } from "../src/RngWitnet.sol";

contract RngWitnetTest is Test {

    IWitnetRandomness witnetRandomness;
    RngWitnet rngWitnet;

    function setUp() public {
        witnetRandomness = IWitnetRandomness(makeAddr("WitnetRandomness"));
        rngWitnet = new RngWitnet(witnetRandomness);
        vm.deal(address(this), 1000e18);
    }

    function testRequestRandomNumber() external {
        vm.mockCall(address(witnetRandomness), 1e18, abi.encodeWithSelector(IWitnetRandomness.randomize.selector), abi.encode(0.5e18));
        (uint32 requestId, uint256 lockBlock) = rngWitnet.requestRandomNumber{value: 1e18}(1e18);
        assertEq(requestId, 1);
        assertEq(lockBlock, block.number);
        assertEq(address(rngWitnet.getRequestor(address(this))).balance, 1e18, "witnet balance should be 1e18");
    }

    function testStartDraw() public {
        DrawManager drawManager = DrawManager(makeAddr("DrawManager"));
        vm.mockCall(address(drawManager), abi.encodeWithSelector(drawManager.startDraw.selector, address(this), 1), abi.encode(1));
        vm.mockCall(address(witnetRandomness), 1e18, abi.encodeWithSelector(IWitnetRandomness.randomize.selector), abi.encode(0.5e18));
        rngWitnet.startDraw{value: 1e18}(1e18, drawManager, address(this));
        assertEq(address(rngWitnet.getRequestor(address(this))).balance, 1e18, "witnet balance should be 1e18");
    }

    function testWithdraw() public {
        vm.mockCall(address(witnetRandomness), 1e18, abi.encodeWithSelector(IWitnetRandomness.randomize.selector), abi.encode(0.5e18));
        rngWitnet.requestRandomNumber{value: 1e18}(1e18);
        rngWitnet.withdraw();
        assertEq(address(this).balance, 1000e18, "balance is restored");
    }

    receive() external payable {}
}
