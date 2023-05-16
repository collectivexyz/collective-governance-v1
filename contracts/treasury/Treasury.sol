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

import {Constant} from "../../contracts/Constant.sol";
import {TimeLock} from "../../contracts/treasury/TimeLock.sol";
import {Vault} from "../../contracts/treasury/Vault.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";


/**
 * @notice Custom multisig treasury for ETH
 */
contract Treasury is Vault {
    mapping(address => Payment) private _payment;

    TimeLock private immutable _timeLock;
    AddressCollection private _approverSet;

    uint256 public immutable _minimumApprovalCount;

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
        if(!_approverSet.contains(msg.sender)) revert NotApprover(msg.sender);
        _;
    }

    modifier requireNotPending(address _to) {
        Payment memory _pay = _payment[_to];
        if(_pay.scheduleTime > 0) revert TransactionInProgress(_to);
        _;
    }

    modifier requirePayee(address _to) {
        Payment memory _pay = _payment[_to];
        if(_pay.approvalCount < _minimumApprovalCount) revert NotPending(_to);
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
        if (_quantity == 0) revert NoDeposit();
        emit Deposit(_quantity);
    }

    function approve(
        address _to,
        uint256 _quantity
    ) public requireApprover requireNotPending(_to) {
        uint256 availableQty = balance();
        if (availableQty < _quantity) {
            revert InsufficientBalance(_quantity, availableQty);
        }
        Payment storage _pay = _payment[_to];
        if(_pay.approvalCount < _minimumApprovalCount) {
            _pay.approvalCount += 1;
            if(_pay.approvalCount == 1 && _pay.quantity == 0) {
                _pay.quantity = _quantity;
            } else if(_pay.quantity != _quantity) {
                revert ApprovalNotMatched(msg.sender, _quantity, _pay.quantity);
            }
        } 
        
        if(_pay.approvalCount == _minimumApprovalCount) {
            uint256 scheduleTime = getBlockTimestamp() + _timeLock._lockTime();
            _pay.scheduleTime = scheduleTime;
            _timeLock.queueTransaction(_to, _pay.quantity, "", "", _pay.scheduleTime);
            emit Withdraw(_pay.quantity, _to, _pay.scheduleTime);
        }
    }

    function pay() public {
        pay(msg.sender);
    }

    function pay(address _to) public requirePayee(_to) {
        Payment storage _pay = _payment[_to];
        uint256 scheduleTime = _pay.scheduleTime;
        uint256 quantity = _pay.quantity;
        _timeLock.executeTransaction(_to, quantity, "", "", scheduleTime);
        emit PaymentSent(quantity, _to);
        clear(_to);
    }

    function cancel(address _to) public requireApprover {
        Payment memory _pay = _payment[_to];
        if (_pay.scheduleTime == 0) {
            revert NotPending(_to);
        }
        _timeLock.cancelTransaction(_to, _pay.quantity, "", "", _pay.scheduleTime);
        clear(_to);
    }

    function balance(address _from) public view returns (uint256) {
        Payment memory _pay = _payment[_from];
        if(_pay.approvalCount >= _minimumApprovalCount) {
            return _pay.quantity;
        }
        return 0;
    }

    function clear(address _to) private {
        _payment[_to] = Payment(0, 0, 0);
        delete _payment[_to];
    }

    function getBlockTimestamp() private view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    function balance() private view returns (uint256) {
        return address(this).balance;
    }
}