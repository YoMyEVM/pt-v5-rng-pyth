// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";
import { IWitnetRandomness, WitnetOracle, WitnetV2 } from "witnet/interfaces/IWitnetRandomness.sol";
import { RngWitnet } from "../src/RngWitnet.sol";

contract RngWitnetTest is Test {

    IWitnetRandomness witnetRandomness;
    WitnetOracle witnet;
    RngWitnet rngWitnet;

    function setUp() public {
        witnet = WitnetOracle(makeAddr("WitnetOracle"));
        vm.etch(address(witnet), "witnet" );
        witnetRandomness = IWitnetRandomness(makeAddr("WitnetRandomness"));
        vm.etch(address(witnetRandomness), "witnetRandomness" );
        vm.mockCall(address(witnetRandomness), 0, abi.encodeWithSelector(witnetRandomness.witnet.selector), abi.encode(address(witnet)));
        rngWitnet = new RngWitnet(witnetRandomness);
        vm.deal(address(this), 1000e18);
    }

    function testRequestRandomNumber() external {
        vm.mockCall(address(witnetRandomness), 1e18, abi.encodeWithSelector(IWitnetRandomness.randomize.selector), abi.encode(0.5e18));
        (uint32 requestId, uint256 lockBlock, uint256 cost) = rngWitnet.requestRandomNumber{value: 1e18}(1e18);
        assertEq(requestId, 1);
        assertEq(lockBlock, block.number);
        assertEq(cost, 0.5e18);
        assertEq(address(rngWitnet.getRequestor(address(this))).balance, 1e18, "witnet balance should be 1e18");
        assertEq(rngWitnet.requestedAtBlock(requestId), block.number, "requestedAtBlock(requestId)");
        assertEq(rngWitnet.getLastRequestId(), requestId, "getLastRequestId()");
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

    function testEstimateRandomizeFee() public {
        vm.mockCall(address(witnetRandomness), abi.encodeWithSelector(witnetRandomness.estimateRandomizeFee.selector, 100e4), abi.encode(111e18));
        assertEq(rngWitnet.estimateRandomizeFee(100e4), 111e18);
    }

    function testIsRequestComplete() public {
        (uint32 requestId,,) = requestRandomNumber();
        vm.mockCall(address(witnetRandomness), abi.encodeWithSelector(witnetRandomness.isRandomized.selector, requestId), abi.encode(true));
        assertEq(rngWitnet.isRequestComplete(requestId), true);
    }

    function testIsRequestFailed() public {
        (,uint256 lockBlock,) = requestRandomNumber();

        vm.mockCall(address(witnetRandomness), abi.encodeWithSelector(witnetRandomness.getRandomizeData.selector, lockBlock), abi.encode(999, 0, 0));

        vm.mockCall(address(witnet), abi.encodeWithSelector(witnet.getQueryResponseStatus.selector, 999), abi.encode(WitnetV2.ResponseStatus.Ready));
        assertEq(rngWitnet.isRequestFailed(1), false);

        vm.mockCall(address(witnet), abi.encodeWithSelector(witnet.getQueryResponseStatus.selector, 999), abi.encode(WitnetV2.ResponseStatus.Error));
        assertEq(rngWitnet.isRequestFailed(1), true);
    }

    function testRandomNumber() public {
        (uint32 requestId,,) = requestRandomNumber();
        vm.mockCall(address(witnetRandomness), abi.encodeWithSelector(witnetRandomness.fetchRandomnessAfter.selector, requestId), abi.encode(777));
        assertEq(rngWitnet.randomNumber(requestId), 777);
    }

    function requestRandomNumber() internal returns (uint32 requestId, uint256 lockBlock, uint256 cost) {
        vm.mockCall(address(witnetRandomness), 1e18, abi.encodeWithSelector(witnetRandomness.randomize.selector), abi.encode(0.5e18));
        (requestId, lockBlock, cost) = rngWitnet.requestRandomNumber{value: 1e18}(1e18);
    }

    receive() external payable {}
}
