// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

contract Requestor {
    error NoBalanceToWithdraw();
    error TransferFailed();

    /// @notice Withdraws balance from this contract to a target address
    function withdrawTo(address payable _to) external {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert NoBalanceToWithdraw();
        }

        (bool success, ) = _to.call{ value: balance }("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /// @notice Allows this contract to receive ETH
    receive() external payable {}
}
