// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";
import { IEntropy } from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import { RngPyth, UnknownRequest } from "../src/RngPyth.sol";

contract RngPythTest is Test {
    IEntropy pythEntropy;
    RngPyth rngPyth;

    address defaultProvider;

    function setUp() public {
        pythEntropy = IEntropy(makeAddr("PythEntropy"));
        vm.etch(address(pythEntropy), "pythEntropy");
        rngPyth = new RngPyth(pythEntropy);
        vm.deal(address(this), 1000e18);

        defaultProvider = makeAddr("DefaultProvider");
    }

    /// @dev Helper function to mock provider and fee.
    function mockProviderAndFee(uint256 fee) internal {
        vm.mockCall(
            address(pythEntropy),
            abi.encodeWithSelector(pythEntropy.getDefaultProvider.selector),
            abi.encode(defaultProvider)
        );
        vm.mockCall(
            address(pythEntropy),
            abi.encodeWithSelector(pythEntropy.getFee.selector, defaultProvider),
            abi.encode(fee)
        );
    }

    /// @dev Mock requestWithCallback to return a sequence number equal to requestId.
    ///      We assume rngPaymentAmount uniquely identifies a request and use it as sequenceNumber.
    function mockRequestWithCallback(uint256 rngPaymentAmount, uint64 sequenceNumber) internal {
        vm.mockCall(
            address(pythEntropy),
            abi.encodeWithSelector(
                IEntropy.requestWithCallback.selector,
                defaultProvider,
                bytes32(rngPaymentAmount)
            ),
            abi.encode(sequenceNumber)
        );
    }

    function test_requestRandomNumber() external {
        // Mock fee and provider
        mockProviderAndFee(0.5e18);
        // Mock requestWithCallback to return sequenceNumber = 1
        mockRequestWithCallback(1e18, 1);

        (uint32 requestId, uint256 lockBlock) = rngPyth.requestRandomNumber{value: 1e18}(1e18);
        assertEq(requestId, 1, "request id");
        assertEq(lockBlock, block.number, "lockBlock");
        assertEq(rngPyth.requestedAtBlock(requestId), block.number, "requestedAtBlock(requestId)");
    }

    function test_startDraw() public {
        DrawManager drawManager = DrawManager(makeAddr("DrawManager"));

        // Mock fee and provider
        mockProviderAndFee(0.5e18);
        // Mock requestWithCallback for startDraw (which calls _requestRandomNumber internally)
        // We'll assume rngPaymentAmount = 1e18 again and sequenceNumber = 1
        mockRequestWithCallback(1e18, 1);

        // Mock drawManager.startDraw
        vm.mockCall(
            address(drawManager),
            abi.encodeWithSelector(drawManager.startDraw.selector, address(this), 1),
            abi.encode(1)
        );

        // Fund rngPyth if needed
        payable(address(rngPyth)).transfer(1e18);

        rngPyth.startDraw{value: 1e18}(1e18, drawManager, address(this));
    }

    function test_withdraw() public {
        // Fund rngPyth before calling withdraw
        payable(address(rngPyth)).transfer(1e18);

        uint256 beforeBalance = address(this).balance;
        rngPyth.withdraw();
        assertEq(address(this).balance, beforeBalance + 1e18, "balance is restored");
    }

    function test_entropyCallback() public {
        // No request made here; just simulating callback logic
        // In a real test scenario, you'd have requested a random number first.
        uint64 sequenceNumber = 123;
        address provider = defaultProvider;
        bytes32 randomNumber = bytes32(uint256(777));

        rngPyth.testEntropyCallback(sequenceNumber, provider, randomNumber);
        // If needed, you can now call isRequestComplete() or randomNumber(sequenceNumber)
        // after simulating that sequenceNumber = requestId. But no request was actually made.
        // This test just checks that entropyCallback doesn't revert.
    }

    function test_isRequestComplete() public {
        mockProviderAndFee(0.5e18);
        // Request a random number
        mockRequestWithCallback(1e18, 1);
        (uint32 requestId,) = rngPyth.requestRandomNumber{value: 1e18}(1e18);

        // Simulate callback to fulfill the request
        rngPyth.testEntropyCallback(requestId, address(this), bytes32(uint256(777)));

        // Now should be complete
        assertEq(rngPyth.isRequestComplete(requestId), true, "request should be complete after callback");
    }

    function test_isRequestComplete_UnknownRequest() public {
        vm.expectRevert(abi.encodeWithSelector(UnknownRequest.selector, 123));
        rngPyth.isRequestComplete(123);
    }

    function test_randomNumber() public {
        mockProviderAndFee(0.5e18);
        mockRequestWithCallback(1e18, 1);

        // Request a random number first
        (uint32 requestId,) = rngPyth.requestRandomNumber{value: 1e18}(1e18);

        bytes32 randomNumber = bytes32(uint256(777));

        // Now callback to set random result
        rngPyth.testEntropyCallback(requestId, address(this), randomNumber);

        // After callback, random number should be set
        assertEq(rngPyth.randomNumber(requestId), 777, "should return the set random number");
    }

    function test_randomNumber_UnknownRequest() public {
        vm.expectRevert(abi.encodeWithSelector(UnknownRequest.selector, 123));
        rngPyth.randomNumber(123);
    }

    function requestRandomNumber() internal returns (uint32 requestId, uint256 lockBlock) {
        mockProviderAndFee(0.5e18);
        mockRequestWithCallback(1e18, 1);
        (requestId, lockBlock) = rngPyth.requestRandomNumber{value: 1e18}(1e18);
    }

    receive() external payable {}
}
