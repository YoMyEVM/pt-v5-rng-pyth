// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IWitnetRandomness } from "witnet/interfaces/IWitnetRandomness.sol";

contract Requestor {
    error NotCreator();

    address public immutable creator;

    constructor() {
        creator = msg.sender;
    }

    function randomize(IWitnetRandomness _witnetRandomness) external payable onlyCreator {
        _witnetRandomness.randomize{ value: msg.value }();
    }

    function withdraw(address payable _to) external onlyCreator {
        _to.transfer(address(this).balance);
    }

    receive() payable external {}

    modifier onlyCreator() {
        if(msg.sender != address(creator)) {
            revert NotCreator();
        }
        _;
    }
}