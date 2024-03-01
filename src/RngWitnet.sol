// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IWitnetRandomness } from "witnet/interfaces/IWitnetRandomness.sol";
import { IRng } from "pt-v5-draw-manager/interfaces/IRng.sol";
import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";

import { Requestor } from "./Requestor.sol";

contract RngWitnet is IRng {
    error NoPayment();

    event RandomNumberRequested(
        uint32 indexed requestId,
        address indexed sender
    );

    IWitnetRandomness public immutable witnetRandomness;

    mapping(address user => Requestor) public requestors;

    uint32 public lastRequestId;

    mapping(uint32 requestId => uint256 lockBlock) public requests;

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

    function requestedAtBlock(uint32 requestId) external override view returns (uint256) {
        return requests[requestId];
    }

    /**
    * @notice Gets the last request id used by the RNG service
    * @return requestId The last request id used in the last request
    */
    function getLastRequestId() external view returns (uint32 requestId) {
        return lastRequestId;
    }

    function estimateRandomizeFee(uint256 _gasPrice) external view returns (uint256) {
        return witnetRandomness.estimateRandomizeFee(_gasPrice);
    }

    function requestRandomNumber(uint256 rngPaymentAmount) public payable returns (uint32 requestId, uint256 lockBlock) {
        Requestor requestor = getRequestor(msg.sender);
        unchecked {
            requestId = ++lastRequestId;
            lockBlock = block.number;
        }
        requests[requestId] = lockBlock;
        requestor.randomize{value: msg.value}(rngPaymentAmount, witnetRandomness);

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

    function startDraw(uint256 rngPaymentAmount, DrawManager _drawManager, address _rewardRecipient) external payable {
        (uint32 requestId,) = requestRandomNumber(rngPaymentAmount);
        _drawManager.startDraw(_rewardRecipient, requestId);
    }
}
