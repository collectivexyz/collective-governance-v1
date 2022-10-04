// SPDX-License-Identifier: BSD-3-Clause
/*
 *                          88  88                                   88
 *                          88  88                            ,d     ""
 *                          88  88                            88
 *  ,adPPYba,   ,adPPYba,   88  88   ,adPPYba,   ,adPPYba,  MM88MMM  88  8b       d8   ,adPPYba,
 * a8"     ""  a8"     "8a  88  88  a8P_____88  a8"     ""    88     88  `8b     d8'  a8P_____88
 * 8b          8b       d8  88  88  8PP"""""""  8b            88     88   `8b   d8'   8PP"""""""
 * "8a,   ,aa  "8a,   ,a8"  88  88  "8b,   ,aa  "8a,   ,aa    88,    88    `8b,d8'    "8b,   ,aa
 *  `"Ybbd8"'   `"YbbdP"'   88  88   `"Ybbd8"'   `"Ybbd8"'    "Y888  88      "8"       `"Ybbd8"'
 *
 */
/*
 * BSD 3-Clause License
 *
 * Copyright (c) 2022, collective
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../contracts/Constant.sol";

/**
 * @notice TimeLock transactions until a future time.   This is useful to guarantee that a Transaction
 * is specified in advance of a Governance vote and to prevent it from executing before the end of voting.
 * @dev This is a modified version of Compound Finance TimeLock here
 * https://github.com/compound-finance/compound-protocol/blob/a3214f67b73310d547e00fc578e8355911c9d376/contracts/Timelock.sol
 * Implements Ownable and requires owner for all operations.
 */
contract TimeLock is Ownable {
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed _target,
        uint256 _value,
        string _signature,
        bytes _calldata,
        uint256 _scheduleTime
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed _target,
        uint256 _value,
        string _signature,
        bytes _calldata,
        uint256 _scheduleTime
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed _target,
        uint256 _value,
        string _signature,
        bytes _calldata,
        uint256 _scheduleTime
    );

    uint256 public _lockTime;

    /// @notice table of transaction hashes that map to true if queued
    mapping(bytes32 => bool) public _queuedTransaction;

    /**
     * @param _lockDuration The time delay required for the time lock
     */
    constructor(uint256 _lockDuration) {
        require(_lockDuration >= Constant.TIMELOCK_MINIMUM_DELAY, "Delay too short");
        require(_lockDuration <= Constant.TIMELOCK_MAXIMUM_DELAY, "Delay too long");
        _lockTime = _lockDuration;
    }

    /**
     * @notice Enter a transaction as queued for future execution
     * @param _target the target address for this transaction
     * @param _value the value to pass to the call
     * @param _signature the tranaction signature
     * @param _calldata the call data to pass to the call
     * @param _scheduleTime the expected time when the _target should be available to call
     * @return bytes32 the hash value for the transaction used for the internal index
     */
    function queueTransaction(
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _calldata,
        uint256 _scheduleTime
    ) external onlyOwner returns (bytes32) {
        require(_scheduleTime >= (getBlockTimestamp() + _lockTime), "Scheduled during time lock");

        bytes32 txHash = keccak256(abi.encode(_target, _value, _signature, _calldata, _scheduleTime));
        _queuedTransaction[txHash] = true;

        emit QueueTransaction(txHash, _target, _value, _signature, _calldata, _scheduleTime);
        return txHash;
    }

    /**
     * @notice cancel a queued transaction from the timelock
     * @param _target the target address for this transaction
     * @param _value the value to pass to the call
     * @param _signature the tranaction signature
     * @param _calldata the call data to pass to the call
     * @param _scheduleTime the expected time when the _target should be available to call
     */
    function cancelTransaction(
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _calldata,
        uint256 _scheduleTime
    ) external onlyOwner {
        bytes32 txHash = keccak256(abi.encode(_target, _value, _signature, _calldata, _scheduleTime));
        _queuedTransaction[txHash] = false;
        emit CancelTransaction(txHash, _target, _value, _signature, _calldata, _scheduleTime);
    }

    /**
     * @notice execute the scheduled transaction
     * @param _target the target address for this transaction
     * @param _value the value to pass to the call
     * @param _signature the tranaction signature
     * @param _calldata the call data to pass to the call
     * @param _scheduleTime the expected time when the _target should be available to call
     */
    function executeTransaction(
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _calldata,
        uint256 _scheduleTime
    ) external payable onlyOwner returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(_target, _value, _signature, _calldata, _scheduleTime));
        require(_queuedTransaction[txHash], "Not queued");
        require(getBlockTimestamp() >= _scheduleTime, "Transaction is locked");
        require(getBlockTimestamp() <= (_scheduleTime + Constant.TIMELOCK_GRACE_PERIOD), "Transaction is stale.");

        _queuedTransaction[txHash] = false;

        bytes memory callData;

        if (bytes(_signature).length == 0) {
            callData = _calldata;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(_signature))), _calldata);
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = _target.call{value: _value}(callData);
        require(success, "Timelock execution reverted.");

        emit ExecuteTransaction(txHash, _target, _value, _signature, _calldata, _scheduleTime);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }
}
