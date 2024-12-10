// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { IEntropy } from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import { IRng } from "pt-v5-draw-manager/interfaces/IRng.sol";
import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";

error UnknownRequest(uint32 requestId);
error InsufficientFee(uint256 required, uint256 provided);
error NoBalanceToWithdraw();

contract RngPyth is IRng, IEntropyConsumer {
    IEntropy public immutable PYTH_ENTROPY;

    uint32 public lastRequestId;
    mapping(uint32 => uint256) public requests;
    mapping(uint32 => bytes32) private randomResults;

    event RandomNumberRequested(uint32 indexed requestId, address indexed sender, uint256 fee);
    event RandomNumberFulfilled(uint32 indexed requestId, bytes32 randomNumber);

    constructor(IEntropy _pythEntropy) {
        PYTH_ENTROPY = _pythEntropy;
    }

    function _requestRandomNumber(uint256 rngPaymentAmount) internal returns (uint32 requestId, uint256 lockBlock) {
        address provider = PYTH_ENTROPY.getDefaultProvider();
        uint256 fee = PYTH_ENTROPY.getFee(provider);
        if (msg.value < fee) {
            revert InsufficientFee(fee, msg.value);
        }

        unchecked {
            requestId = ++lastRequestId;
            lockBlock = block.number;
        }

        requests[requestId] = lockBlock;

        // Request randomness from Pyth
        PYTH_ENTROPY.requestWithCallback{ value: fee }(provider, bytes32(rngPaymentAmount));
        emit RandomNumberRequested(requestId, msg.sender, fee);
    }

    function requestRandomNumber(
        uint256 rngPaymentAmount
    ) external payable returns (uint32 requestId, uint256 lockBlock) {
        return _requestRandomNumber(rngPaymentAmount);
    }

    function isRequestComplete(uint32 requestId) external view override returns (bool) {
        if (requests[requestId] == 0) {
            revert UnknownRequest(requestId);
        }
        return randomResults[requestId] != bytes32(0);
    }

    function isRequestFailed(uint32) external pure override returns (bool) {
        return false;
    }

    function requestedAtBlock(uint32 requestId) external view override returns (uint256) {
        if (requests[requestId] == 0) {
            revert UnknownRequest(requestId);
        }
        return requests[requestId];
    }

    function getLastRequestId() external view returns (uint32) {
        return lastRequestId;
    }

    function getEntropy() internal view override returns (address) {
        return address(PYTH_ENTROPY);
    }

    function entropyCallback(uint64 sequenceNumber, address /* _provider */, bytes32 entropyValue) internal override {
        uint32 requestId = uint32(sequenceNumber);
        randomResults[requestId] = entropyValue;
        emit RandomNumberFulfilled(requestId, entropyValue);
    }

    function testEntropyCallback(uint64 sequenceNumber, address provider, bytes32 entropyValue) external {
        entropyCallback(sequenceNumber, provider, entropyValue);
    }

    function randomNumber(uint32 requestId) external view returns (uint256) {
        if (requests[requestId] == 0) {
            revert UnknownRequest(requestId);
        }
        return uint256(randomResults[requestId]);
    }

    function startDraw(
        uint256 rngPaymentAmount,
        DrawManager _drawManager,
        address _rewardRecipient
    ) external payable returns (uint24) {
        (uint32 requestId, ) = _requestRandomNumber(rngPaymentAmount);
        return _drawManager.startDraw(_rewardRecipient, requestId);
    }

    function withdraw() external {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert NoBalanceToWithdraw();
        }
        payable(msg.sender).transfer(balance);
    }

    receive() external payable {}
}
