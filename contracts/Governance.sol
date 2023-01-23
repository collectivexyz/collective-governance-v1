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
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "../contracts/access/Versioned.sol";
import "../contracts/Constant.sol";

/// @title Governance interface
/// @notice Requirements for Governance implementation
/// @custom:type interface
interface Governance is Versioned, IERC165 {
    error NotEnoughChoices();
    error NotPermitted(address sender);
    error CancelNotPossible(uint256 proposalId, address sender);
    error NotSupervisor(uint256 proposalId, address sender);
    error VoteIsOpen(uint256 proposalId);
    error VoteIsClosed(uint256 proposalId);
    error VoteCancelled(uint256 proposalId);
    error VoteVetoed(uint256 proposalId);
    error VoteFinal(uint256 proposalId);
    error VoteNotFinal(uint256 proposalId);
    error ProposalNotSender(uint256 proposalId, address sender);
    error QuorumNotConfigured(uint256 proposalId);
    error VoteInProgress(uint256 proposalId);
    error TransactionExecuted(uint256 proposalId);
    error NotExecuted(uint256 proposalId);
    error InvalidChoice(uint256 proposalId, uint256 choiceId);
    error TransactionSignatureNotMatching(uint256 proposalId, uint256 transactionId);

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

    /// @notice ProposalMeta attached
    event ProposalMeta(uint256 proposalId, uint256 metaId, bytes32 name, string value, address sender);
    /// @notice ProposalChoice Set
    event ProposalChoice(uint256 proposalId, uint256 choiceId, bytes32 name, string description, uint256 transactionId);
    /// @notice The proposal description
    event ProposalDescription(uint256 proposalId, string description, string url);
    /// @notice The proposal is final - vote is ready
    event ProposalFinal(uint256 proposalId, uint256 quorum);
    /// @notice Timing information
    event ProposalDelay(uint256 voteDelay, uint256 voteDuration);

    /// @notice The attached transactions are executed
    event ProposalExecuted(uint256 proposalId, uint256 executedTransactionCount);
    /// @notice The proposal has been vetoed
    event ProposalVeto(uint256 proposalId, address sender);
    /// @notice The contract has been funded to provide gas rebates
    event RebateFund(address sender, uint256 transfer, uint256 totalFund);
    /// @notice Gas rebate payment
    event RebatePaid(address recipient, uint256 rebate, uint256 gasPaid);

    /// @notice Winning choice in choice vote
    event WinningChoice(uint256 proposalId, bytes32 name, string description, uint256 transactionId, uint256 voteCount);

    /// @notice propose a vote for the community
    /// @return uint256 The id of the new proposal
    function propose() external returns (uint256);

    /// @notice propose a choice vote for the community
    /// @dev Only one new proposal is allowed per msg.sender
    /// @param _choiceCount the number of choices for this vote
    /// @return uint256 The id of the new proposal
    function propose(uint256 _choiceCount) external returns (uint256);

    /// @notice Attach a transaction to the specified proposal.
    ///         If successfull, it will be executed when voting is ended.
    /// @dev required prior to calling configure
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

    /// @notice describe a proposal
    /// @param _proposalId the numeric id of the proposed vote
    /// @param _description the description
    /// @param _url for proposed vote
    /// @dev required prior to calling configure
    function describe(uint256 _proposalId, string memory _description, string memory _url) external;

    /// @notice set a choice by choice id
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _name the name of the metadata field
    /// @param _description the detailed description of the choice
    /// @param _transactionId The id of the transaction to execute
    function setChoice(
        uint256 _proposalId,
        uint256 _choiceId,
        bytes32 _name,
        string memory _description,
        uint256 _transactionId
    ) external;

    /// @notice attach arbitrary metadata to proposal
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _name the name of the metadata field
    /// @param _value the value of the metadata
    /// @return uint256 the metadata id
    function addMeta(uint256 _proposalId, bytes32 _name, string memory _value) external returns (uint256);

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
    function configure(uint256 _proposalId, uint256 _quorumThreshold, uint256 _requiredDelay, uint256 _requiredDuration) external;

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure returns (string memory);

    /// @notice return the name of the community
    /// @return bytes32 the community name
    function community() external view returns (bytes32);

    /// @notice return the community url
    /// @return string memory representation of url
    function url() external view returns (string memory);

    /// @notice return community description
    /// @return string memory representation of community description
    function description() external view returns (string memory);

    /// @notice start the voting process by proposal id
    /// @param _proposalId The numeric id of the proposed vote
    function startVote(uint256 _proposalId) external;

    /// @notice test if an existing proposal is open
    /// @param _proposalId The numeric id of the proposed vote
    /// @return bool True if the proposal is open
    function isOpen(uint256 _proposalId) external view returns (bool);

    /// @notice end voting on an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    function endVote(uint256 _proposalId) external;
}
