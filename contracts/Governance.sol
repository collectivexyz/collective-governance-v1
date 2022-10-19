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

import "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @title Governance interface
/// @notice Requirements for Governance implementation
/// @custom:type interface
interface Governance is IERC165 {
    /// @notice The timelock requirement
    event TimeLockCreated(address timeLock, uint256 lockTime);
    /// @notice A new proposal was created
    event ProposalCreated(address sender, uint256 proposalId);
    /// @notice transaction attached to proposal
    event ProposalTransactionAttached(
        address creator,
        uint256 proposalId,
        uint256 transactionId,
        address target,
        uint256 value,
        uint256 scheduleTime,
        bytes32 txHash
    );
    /// @notice transaction canceled on proposal
    event ProposalTransactionCancelled(
        uint256 proposalId,
        uint256 transactionId,
        address target,
        uint256 value,
        uint256 scheduleTime,
        bytes32 txHash
    );
    /// @notice transaction executed on proposal
    event ProposalTransactionExecuted(
        uint256 proposalId,
        uint256 transactionId,
        address target,
        uint256 value,
        uint256 scheduleTime,
        bytes32 txHash
    );
    /// @notice The proposal is now open for voting
    event ProposalOpen(uint256 proposalId);
    /// @notice Voting is now closed for voting
    event ProposalClosed(uint256 proposalId);
    /// @notice The attached transactions are executed
    event ProposalExecuted(uint256 proposalId, uint256 executedTransactionCount);

    /// @notice propose a vote for the community
    /// @return uint256 The id of the new proposal
    function propose() external returns (uint256);

    /// @notice Attach a transaction to the specified proposal.
    ///         If successfull, it will be executed when voting is ended.
    /// @dev must be called prior to configuration
    /// @param _proposalId the id of the proposal
    /// @param _target the target address for this transaction
    /// @param _value the value to pass to the call
    /// @param _signature the tranaction signature
    /// @param _calldata the call data to pass to the call
    /// @param _scheduleTime the expected call time, within the timelock grace,
    ///        for the transaction
    /// @return uint256 the transactionId
    function attachTransaction(
        uint256 _proposalId,
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _calldata,
        uint256 _scheduleTime
    ) external returns (uint256);

    /// @notice cancel a proposal if it is not yet open
    /// @param _proposalId The numeric id of the proposed vote
    function cancel(uint256 _proposalId) external;

    /// @notice configure an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _quorumRequired The threshold of participation that is required for a successful conclusion of voting
    function configure(uint256 _proposalId, uint256 _quorumRequired) external;

    /// @notice configure an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _quorumThreshold The threshold of participation that is required for a successful conclusion of voting
    /// @param _requiredDelay The minimum time required before the start of voting
    /// @param _requiredDuration The minimum time for voting to proceed before ending the vote is allowed
    function configure(
        uint256 _proposalId,
        uint256 _quorumThreshold,
        uint256 _requiredDelay,
        uint256 _requiredDuration
    ) external;

    /// @notice return the address of the internal vote data store
    /// @return address The address of the store
    function getStorageAddress() external view returns (address);

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure returns (string memory);

    /// @notice return the version of this implementation
    /// @return uint32 version number
    function version() external pure returns (uint32);

    /// @notice return the name of the community
    /// @return bytes32 the community name
    function community() external view returns (bytes32);

    /// @notice return the community url
    /// @return string memory representation of url
    function url() external view returns (string memory);

    /// @notice return community description
    /// @return string memory representation of community description
    function description() external view returns (string memory);
}
