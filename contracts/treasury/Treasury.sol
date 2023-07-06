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
 * Copyright (c) 2023, collective
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

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { Constant } from "../../contracts/Constant.sol";
import { TimeLock } from "../../contracts/treasury/TimeLock.sol";
import { Vault } from "../../contracts/treasury/Vault.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";
import { Transaction, getHash } from "../../contracts/collection/TransactionSet.sol";

/**
 * @notice Custom multisig treasury for ETH
 */
contract Treasury is Vault, ReentrancyGuard {
    mapping(address => Payment) private _payment;

    TimeLock private immutable _timeLock;
    AddressCollection public immutable _approverSet;
    uint256 public immutable _minimumApprovalCount;

    uint256 private _pendingPayment = 0;

    /**
     * construct the Treasury
     * @param _minimumApprovalRequirement The number number of approvers before a transaction can be pending
     * @param _minimumTimeLock The minimum time for any transaction to be processed
     * @param _approver A set of addresses to be used as approvers
     */
    constructor(uint256 _minimumApprovalRequirement, uint256 _minimumTimeLock, AddressCollection _approver) {
        _timeLock = new TimeLock(_minimumTimeLock);
        _approverSet = Constant.from(_approver);
        _minimumApprovalCount = _minimumApprovalRequirement;
    }

    modifier requireApprover() {
        if (!_approverSet.contains(msg.sender)) revert NotApprover(msg.sender);
        _;
    }

    modifier requireNotPending(address _to) {
        Payment memory _pay = _payment[_to];
        if (_pay.scheduleTime > 0) revert TransactionInProgress(_to);
        _;
    }

    modifier requirePayee(address _to) {
        Payment memory _pay = _payment[_to];
        if (_pay.approvalCount < _minimumApprovalCount) revert NotPending(_to);
        _;
    }

    modifier requireSufficientBalance(uint256 _quantity) {
        uint256 availableQty = address(this).balance - _pendingPayment;
        if (availableQty < _quantity) {
            revert InsufficientBalance(_quantity, availableQty);
        }
        _;
    }

    receive() external payable {
        deposit();
    }

    // solhint-disable-next-line payable-fallback
    fallback() external {
        pay();
    }

    /// @notice deposit msg.value in the vault
    /// @dev payable
    function deposit() public payable {
        uint256 _quantity = msg.value;
        if (_quantity == 0) revert NoDeposit(msg.sender);
        emit Deposit(_quantity);
    }

    /// @notice approve transfer of _quantity
    /// @param _to the address approved to withdraw the amount
    /// @param _quantity the amount of the approved transfer
    function approve(
        address _to,
        uint256 _quantity
    ) public requireApprover requireNotPending(_to) requireSufficientBalance(_quantity) {
        initializeSlot(_to);
        addApproval(_to, msg.sender, _quantity);
        uint256 scheduleTime = getBlockTimestamp() + _timeLock._lockTime();
        enqueueLockTransaction(_to, scheduleTime);
    }

    /**
     * @notice Approve and schedule a payment to recipient in one transaction.
     *
     * Each required approver must individually sign a message that
     * represents the standardized transaction for the payment transfer
     * as follows
     *
     * keccak256(abi.encode(_to, _quantity, "", "", _scheduleTime))
     *
     * Each approver must sign off chain and the signatures passed to this function.
     *
     * @dev _scheduleTime is subject to timelock constraints
     *
     * @param _to the address of the recipient
     * @param _quantity to approve
     * @param _scheduleTime the scheduled time
     * @param _signature array of signature as bytes
     */
    function approveMulti(
        address _to,
        uint256 _quantity,
        uint256 _scheduleTime,
        bytes[] memory _signature
    ) external requireApprover requireNotPending(_to) requireSufficientBalance(_quantity) {
        Transaction memory transaction = Transaction(_to, _quantity, "", "", _scheduleTime);
        bytes32 transactionHash = getHash(transaction);
        bytes32 signedMessageHash = ECDSA.toEthSignedMessageHash(transactionHash);
        initializeSlot(_to);
        for (uint i = 0; i < _signature.length; ++i) {
            bytes memory signature = _signature[i];
            address signer = verifySignature(signedMessageHash, _approverSet, signature);
            addApproval(_to, signer, _quantity);
            enqueueLockTransaction(_to, _scheduleTime);
            emit SignatureVerified(signer, signedMessageHash);
        }
    }

    /// @notice pay quantity to msg.sender
    function pay() public {
        transferTo(msg.sender);
    }

    /// @notice transfer approved quantity to
    /// @dev requires approval
    /// @param _to the address to pay
    function transferTo(address _to) public requirePayee(_to) {
        Payment storage _pay = _payment[_to];
        transferToLock(_pay.quantity, _to, _pay.scheduleTime);
        _timeLock.executeTransaction(_to, _pay.quantity, "", "", _pay.scheduleTime);
        emit PaymentSent(_pay.quantity, _to);
        clear(_to);
    }

    /// @notice cancel the approved payment
    /// @dev It is only safe to cancel a transaction within TIMELOCK_MINIMUM_DELAY (currently 1 day)
    /// seconds of the eventual schedule time.   An approval may be possible to 'replay' and
    /// succeed prior to that time.    Later, any replay approval would fail the timelock constraints.
    ///
    /// It is advisable to schedule all transactions at or near TIMELOCK_MINIMUM_DELAY.
    /// A grace of a few minutes might be useful to ensure transactions complete safely, but the
    /// operator should be aware of these timings and careful that cancellations are timely.
    /// @param _to the approved recipient
    function cancel(address _to) public requireApprover {
        Payment memory _pay = _payment[_to];
        if (_pay.scheduleTime == 0) {
            revert NotPending(_to);
        }
        _pendingPayment -= _pay.quantity;
        _timeLock.cancelTransaction(_to, _pay.quantity, "", "", _pay.scheduleTime);
        emit TransactionCancelled(_pay.quantity, _to, _pay.scheduleTime);
        clear(_to);
    }

    /// @notice balance approved for the specified address
    /// @param _from the address of the wallet to check
    function balance(address _from) public view returns (uint256) {
        Payment memory _pay = _payment[_from];
        if (_pay.approvalCount >= _minimumApprovalCount) {
            return _pay.quantity;
        }
        return 0;
    }

    /// @notice total balance on treasury
    function balance() public view override(Vault) returns (uint256) {
        return address(this).balance - _pendingPayment;
    }

    function verifySignature(
        bytes32 _agreementHash,
        AddressCollection _approvedSet,
        bytes memory _signature
    ) private view returns (address) {
        address signatureAddress = ECDSA.recover(_agreementHash, _signature);
        if (!_approvedSet.contains(signatureAddress)) revert SignatureNotAccepted(msg.sender, signatureAddress);
        return signatureAddress;
    }

    function clear(address _to) private {
        Payment storage _pay = _payment[_to];
        _pay.quantity = 0;
        _pay.scheduleTime = 0;
        _pay.approvalCount = 0;
        delete _payment[_to];
    }

    function getBlockTimestamp() private view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    /// make sure timelock has funds for payment
    function transferToLock(uint256 _quantity, address _to, uint256 _scheduleTime) private nonReentrant {
        _pendingPayment -= _quantity;
        address payable lockBalance = payable(address(_timeLock));
        // see here for details: https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/external-calls/#favor-pull-over-push-for-external-calls
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = lockBalance.call{value: _quantity}("");
        if (!success) revert TimeLockTransferFailed(_quantity, _to, _scheduleTime);
        emit TreasuryWithdraw(_quantity, _to, _scheduleTime);
    }

    function initializeSlot(address _to) private {
        Payment storage _pay = _payment[_to];
        if (_pay.approvalCount == 0) {
            _pay.approvalSet = Constant.createAddressSet();
            _pay.quantity = 0;
            _pay.scheduleTime = 0;
            _pay.approvalCount = 0;
        }
    }

    function addApproval(address _to, address _from, uint256 _quantity) private {
        Payment storage _pay = _payment[_to];
        if (!_pay.approvalSet.set(_from)) {
            revert DuplicateApproval(_from);
        }
        _pay.approvalCount += 1;
        if (_pay.approvalCount == 1 && _pay.quantity == 0) {
            _pay.quantity = _quantity;
        } else if (_pay.quantity != _quantity) {
            revert ApprovalNotMatched(msg.sender, _quantity, _pay.quantity);
        }
    }

    function enqueueLockTransaction(address _to, uint256 _scheduleTime) private {
        Payment storage _pay = _payment[_to];
        if (_pay.approvalCount == _minimumApprovalCount) {
            _pay.scheduleTime = _scheduleTime;
            // delegate to timelock for execution
            _timeLock.queueTransaction(_to, _pay.quantity, "", "", _pay.scheduleTime);
            _pendingPayment += _pay.quantity;
            emit TransactionApproved(_pay.quantity, _to, _pay.scheduleTime);
        }
    }
}
