// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IWitnetRandomness } from "witnet/interfaces/IWitnetRandomness.sol";
import { RNGInterface } from "rng-contracts/RNGInterface.sol";

import { Requestor } from "./Requestor.sol";

contract RngWitnet is RNGInterface {
    error NoPayment();

    IWitnetRandomness public immutable witnetRandomness;

    mapping(address user => Requestor) public requestors;

    uint32 public lastRequestId;

    mapping(uint32 requestId => uint32 lockBlock) public requests;

    constructor(IWitnetRandomness _witnetRandomness) {
        witnetRandomness = _witnetRandomness;
    }

    function getRequestor(address user) public returns (Requestor) {
        Requestor requestor = requestors[user];
        if (address(requestor) == address(0)) {
            requestor = new Requestor();
            requestors[user] = requestor;
        }
        return requestor;
    }

    /**
    * @notice Gets the last request id used by the RNG service
    * @return requestId The last request id used in the last request
    */
    function getLastRequestId() external view returns (uint32 requestId) {
        return lastRequestId;
    }

    /**
    * @notice Gets the Fee for making a Request against an RNG service
    * @return feeToken The address of the token that is used to pay fees
    * @return requestFee The fee required to be paid to make a request
    */
    function getRequestFee() external view returns (address feeToken, uint256 requestFee) {
        return (address(0), 0);
    }

    function estimateRandomizeFee(uint256 _gasPrice) external view returns (uint256) {
        return witnetRandomness.estimateRandomizeFee(_gasPrice);
    }

    /**
    * @notice Sends a request for a random number to the 3rd-party service
    * @dev Some services will complete the request immediately, others may have a time-delay
    * @dev Some services require payment in the form of a token, such as $LINK for Chainlink VRF
    * @return requestId The ID of the request used to get the results of the RNG service
    * @return lockBlock The block number at which the RNG service will start generating time-delayed randomness.
    * The calling contract should "lock" all activity until the result is available via the `requestId`
    */
    function requestRandomNumber() external payable returns (uint32 requestId, uint32 lockBlock) {
        if (msg.value == 0) {
            revert NoPayment();
        }
        Requestor requestor = getRequestor(msg.sender);
        unchecked {
            requestId = ++lastRequestId;
            lockBlock = uint32(block.number);
        }
        requests[requestId] = lockBlock;
        requestor.randomize{value: msg.value}(witnetRandomness);

        emit RandomNumberRequested(requestId, msg.sender);
    }

    function withdraw() external {
        Requestor requestor = requestors[msg.sender];
        requestor.withdraw(payable(msg.sender));
    }

    /**
    * @notice Checks if the request for randomness from the 3rd-party service has completed
    * @dev For time-delayed requests, this function is used to check/confirm completion
    * @param requestId The ID of the request used to get the results of the RNG service
    * @return isCompleted True if the request has completed and a random number is available, false otherwise
    */
    function isRequestComplete(uint32 requestId) external view returns (bool isCompleted) {
        return witnetRandomness.isRandomized(requests[requestId]);
    }

    /**
    * @notice Gets the random number produced by the 3rd-party service
    * @param requestId The ID of the request used to get the results of the RNG service
    * @return randomNum The random number
    */
    function randomNumber(uint32 requestId) external view returns (uint256 randomNum) {    
        return uint256(witnetRandomness.getRandomnessAfter(requests[requestId]));
    }

    /**
    * @notice Returns the timestamps at which the request was completed
    * @param requestId The ID of the request used to get the results of the RNG service
    * @return completedAtTimestamp The timestamp at which the request was completed
    */
    function completedAt(uint32 requestId) external view returns (uint64 completedAtTimestamp) {
        return 0;
    }

}