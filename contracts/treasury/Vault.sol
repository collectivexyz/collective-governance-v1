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

/**
 * @notice Vault interface for treasury implementation
 */
/// @custom:type interface
interface Vault {
    /// Please deposit or withdraw instead
    error FallbackNotPermitted();
    /// deposit sent but value was nil
    error NoDeposit();
    /// An approver is required for this operation
    error NotApprover(address sender);
    /// attempt to approve transaction when a transaction is already in progress
    error TransactionInProgress(address sender);
    /// no transaction is pending, approve first
    error NotPending(address payee);
    /// approved quantity disagreement
    error ApprovalNotMatched(address sender, uint256 quantity, uint256 expected);
    /// quantity not available for approval
    error InsufficientBalance(uint256 quantity, uint256 available);

    /// a deposit has been recieved
    event Deposit(uint256 quantity);
    /// withdraw completed
    event Withdraw(uint256 quantity, address _to, uint256 timeAvailable);
    /// payment completed
    event PaymentSent(uint256 quantity, address _to);


    struct Payment {
        uint256 quantity;
        uint256 scheduleTime;
        uint256 approvalCount;
    }

    /// @notice deposit msg.value in the vault
    /// @dev payable
    function deposit() external payable;

    /// @notice approve transfer of _quantity
    /// @param _to the address approved to withdraw the amount
    /// @param _quantity the amount of the approved transfer
    function approve(
        address _to,
        uint256 _quantity
    ) external;

    /// @notice pay quantity to msg.sender
    function pay() external;

    /// @notice pay approved quantity to
    /// @dev requires approval
    /// @param _to the address to pay
    function pay(address _to) external;

    /// @notice cancel the approved payment
    /// @param _to the approved recipient
    function cancel(address _to) external;

    /// @notice balance approved for the specified address
    /// @param _from the address of the wallet to check
    function balance(address _from) external view returns (uint256);
}