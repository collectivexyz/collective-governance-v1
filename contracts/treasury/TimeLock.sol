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

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Constant } from "../../contracts/Constant.sol";
import { getHash, Transaction, TransactionSet } from "../../contracts/collection/TransactionSet.sol";
import { TimeLocker } from "../../contracts/treasury/TimeLocker.sol";

/**
 * @notice TimeLock transactions until a future time.   This is useful to guarantee that a Transaction
 * is specified in advance of a vote and to make it impossible to execute before the end of voting.
 *
 * @dev This is a modified version of Compound Finance TimeLock.
 *
 * https://github.com/compound-finance/compound-protocol/blob/a3214f67b73310d547e00fc578e8355911c9d376/contracts/Timelock.sol
 *
 * Implements Ownable and requires owner for all operations.
 */
contract TimeLock is TimeLocker, Ownable {
    uint256 public immutable _lockTime;

    /// @notice table of transaction hashes, map to true if seen by the queueTransaction operation
    mapping(bytes32 => bool) public _queuedTransaction;

    /**
     * @param _lockDuration The time delay required for the time lock
     */
    constructor(uint256 _lockDuration) {
        if (_lockDuration < Constant.TIMELOCK_MINIMUM_DELAY || _lockDuration > Constant.TIMELOCK_MAXIMUM_DELAY) {
            revert RequiredDelayNotInRange(_lockDuration, Constant.TIMELOCK_MINIMUM_DELAY, Constant.TIMELOCK_MAXIMUM_DELAY);
        }
        _lockTime = _lockDuration;
    }

    receive() external payable {
        emit TimelockEth(msg.sender, msg.value);
    }

    // solhint-disable-next-line payable-fallback
    fallback() external {
        revert NotPermitted(msg.sender);
    }

    /**
     * @notice Mark a transaction as queued for this time lock
     * @dev It is only possible to execute a queued transaction.   Queueing in the context of a TimeLock is
     * the process of identifying in advance or naming the transaction to be executed.  Nothing is actually queued.
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
        string calldata _signature,
        bytes calldata _calldata,
        uint256 _scheduleTime
    ) external onlyOwner returns (bytes32) {
        Transaction memory transaction = Transaction(_target, _value, _signature, _calldata, _scheduleTime);
        bytes32 txHash = getHash(transaction);
        uint256 blockTime = getBlockTimestamp();
        uint256 startLock = blockTime + _lockTime;
        uint256 endLock = startLock + Constant.TIMELOCK_GRACE_PERIOD;
        if (_scheduleTime < startLock || _scheduleTime > endLock) {
            revert TimestampNotInLockRange(txHash, blockTime, _scheduleTime, startLock, endLock);
        }
        if (_queuedTransaction[txHash]) revert QueueCollision(txHash);
        setQueue(txHash);
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
        string calldata _signature,
        bytes calldata _calldata,
        uint256 _scheduleTime
    ) external onlyOwner returns (bytes32) {
        Transaction memory transaction = Transaction(_target, _value, _signature, _calldata, _scheduleTime);
        bytes32 txHash = getHash(transaction);
        if (!_queuedTransaction[txHash]) revert NotInQueue(txHash);
        clearQueue(txHash);
        emit CancelTransaction(txHash, _target, _value, _signature, _calldata, _scheduleTime);
        return txHash;
    }

    /**
     * @notice If the time lock is concluded, execute the scheduled transaction.
     * @dev It is only possible to execute a queued transaction therefore anyone may initiate the call
     * @param _target the target address for this transaction
     * @param _value the value to pass to the call
     * @param _signature the tranaction signature
     * @param _calldata the call data to pass to the call
     * @param _scheduleTime the expected time when the _target should be available to call
     * @return bytes The return data from the executed call
     */
    function executeTransaction(
        address _target,
        uint256 _value,
        string calldata _signature,
        bytes calldata _calldata,
        uint256 _scheduleTime
    ) external payable returns (bytes memory) {
        Transaction memory transaction = Transaction(_target, _value, _signature, _calldata, _scheduleTime);
        bytes32 txHash = getHash(transaction);
        if (!_queuedTransaction[txHash]) {
            revert NotInQueue(txHash);
        }
        uint256 blockTime = getBlockTimestamp();
        if (blockTime < _scheduleTime) {
            revert TransactionLocked(txHash, _scheduleTime);
        }
        if (blockTime > (_scheduleTime + Constant.TIMELOCK_GRACE_PERIOD)) {
            revert TransactionStale(txHash);
        }

        clearQueue(txHash);
        bytes memory callData;
        if (bytes(_signature).length == 0) {
            callData = _calldata;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(_signature))), _calldata);
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool ok, bytes memory returnData) = _target.call{ value: _value }(callData);
        if (!ok) revert ExecutionFailed(txHash);
        emit ExecuteTransaction(txHash, _target, _value, _signature, _calldata, _scheduleTime);
        return returnData;
    }

    /**
     * @notice get a queued transaction
     * @param _txHash Transaction hash to check
     * @return bool True if transaction is queued and false otherwise
     */
    function queuedTransaction(bytes32 _txHash) external view returns (bool) {
        return _queuedTransaction[_txHash];
    }

    function setQueue(bytes32 _txHash) private {
        _queuedTransaction[_txHash] = true;
    }

    function clearQueue(bytes32 _txHash) private {
        // overwrite memory to protect against value rebinding
        _queuedTransaction[_txHash] = false;
        delete _queuedTransaction[_txHash];
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }
}
