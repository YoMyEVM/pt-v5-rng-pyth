// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { Requestor } from "../src/Requestor.sol";

contract RequestorTest is Test {
    Requestor requestor;

    function setUp() public {
        requestor = new Requestor();
    }

    function testWithdrawTo() public {
        // Deal this test contract some funds
        vm.deal(address(this), 1e18);
        // Transfer funds to the requestor contract so it has a balance
        payable(address(requestor)).transfer(1e18);

        uint256 beforeBalance = address(this).balance;
        requestor.withdrawTo(payable(address(this)));
        uint256 afterBalance = address(this).balance;

        // afterBalance should now be beforeBalance + 1e18
        assertEq(afterBalance, beforeBalance + 1e18, "Withdraw did not return correct amount");
    }

    // If needed, add a receive function here so this test contract can accept ETH
    receive() external payable {}
}
