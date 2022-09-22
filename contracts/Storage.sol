// SPDX-License-Identifier: BSD-3-Clause
/*
 * BSD 3-Clause License
 *
 * Copyright (c) 2022, Collective.XYZ
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

import "../contracts/VoterClass.sol";
import "../contracts/VoteStrategy.sol";

/// @title Storage interface
/// @notice provides the requirements for Storage contract implementation
/// @custom:type interface
interface Storage is IERC165 {
    // event section
    event InitializeProposal(uint256 proposalId, address owner);
    event AddSupervisor(uint256 proposalId, address supervisor);
    event BurnSupervisor(uint256 proposalId, address supervisor);
    event SetQuorumThreshold(uint256 proposalId, uint256 passThreshold);
    event UndoVoteEnabled(uint256 proposalId);

    event VoteCast(uint256 proposalId, address voter, uint256 shareId, uint256 totalVotesCast);
    event UndoVote(uint256 proposalId, address voter, uint256 shareId, uint256 votesUndone);
    event VoteVeto(uint256 proposalId, address supervisor);
    event VoteReady(uint256 proposalId, uint256 startTime, uint256 endTime);
    event VoteCancel(uint256 proposalId, address supervisor);

    enum Status {
        CONFIG,
        FINAL,
        CANCELLED
    }

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposalSender;
        /// @notice The number of votes in support of a proposal required in
        /// order for a quorum to be reached and for a vote to succeed
        uint256 quorumRequired;
        /// @notice The number of blocks to delay the first vote from voting open
        uint256 voteDelay;
        /// @notice The number of blocks duration for the vote, last vote must be cast prior
        uint256 voteDuration;
        /// @notice The time when voting begins
        uint256 startTime;
        /// @notice The time when voting ends
        uint256 endTime;
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;
        /// @notice Current number of votes for abstaining for this proposal
        uint256 abstentionCount;
        /// @notice Flag marking whether the proposal has been vetoed
        bool isVeto;
        /// @notice Flag marking whether the proposal has been executed
        bool isExecuted;
        /// @notice current status for this proposal
        Status status;
        /// @notice this proposal allows undo votes
        bool isUndoEnabled;
        /// @notice Receipts of ballots for the entire set of voters
        mapping(uint256 => Receipt) voteReceipt;
        /// @notice configured supervisors
        mapping(address => bool) supervisorPool;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice address of voting wallet
        address wallet;
        /// @notice id of reserved shares
        uint256 shareId;
        /// @notice number of votes cast for
        uint256 shareFor;
        /// @notice The number of votes the voter had, which were cast
        uint256 votesCast;
        /// @notice did the voter abstain
        bool abstention;
        /// @notice has this share been reversed
        bool undoCast;
    }

    /// @notice Register a new supervisor on the specified proposal.
    /// The supervisor has rights to add or remove voters prior to start of voting
    /// in a Voter Pool. The supervisor also has the right to veto the outcome of the vote.
    /// @dev requires proposal creator
    /// @param _proposalId the id of the proposal
    /// @param _supervisor the supervisor address
    /// @param _sender original wallet for this request
    function registerSupervisor(
        uint256 _proposalId,
        address _supervisor,
        address _sender
    ) external;

    /// @notice remove a supervisor from the proposal along with its ability to change or veto
    /// @dev requires proposal creator
    /// @param _proposalId the id of the proposal
    /// @param _supervisor the supervisor address
    /// @param _sender original wallet for this request
    function burnSupervisor(
        uint256 _proposalId,
        address _supervisor,
        address _sender
    ) external;

    /// @notice set the minimum number of participants for a successful outcome
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _threshold the quorum number
    /// @param _sender original wallet for this request
    function setQuorumThreshold(
        uint256 _proposalId,
        uint256 _threshold,
        address _sender
    ) external;

    /// @notice enable the undo feature for this vote
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _sender original wallet for this request
    function enableUndoVote(uint256 _proposalId, address _sender) external;

    /// @notice set the delay period required to preceed the vote
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _voteDelay the quorum number
    /// @param _sender original wallet for this request
    function setVoteDelay(
        uint256 _proposalId,
        uint256 _voteDelay,
        address _sender
    ) external;

    /// @notice set the required duration for the vote
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _voteDuration the quorum number
    /// @param _sender original wallet for this request
    function setRequiredVoteDuration(
        uint256 _proposalId,
        uint256 _voteDuration,
        address _sender
    ) external;

    /// @notice get the address of the proposal sender
    /// @param _proposalId the id of the proposal
    /// @return address the address of the sender
    function getSender(uint256 _proposalId) external view returns (address);

    /// @notice get the quorum required
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number required for quorum
    function quorumRequired(uint256 _proposalId) external view returns (uint256);

    /// @notice get the vote delay
    /// @param _proposalId the id of the proposal
    /// @return uint256 the delay
    function voteDelay(uint256 _proposalId) external view returns (uint256);

    /// @notice get the vote duration
    /// @param _proposalId the id of the proposal
    /// @return uint256 the duration
    function voteDuration(uint256 _proposalId) external view returns (uint256);

    /// @notice get the start time
    /// @dev timestamp in epoch seconds since January 1, 1970
    /// @param _proposalId the id of the proposal
    /// @return uint256 the start time
    function startTime(uint256 _proposalId) external view returns (uint256);

    /// @notice get the end time
    /// @dev timestamp in epoch seconds since January 1, 1970
    /// @param _proposalId the id of the proposal
    /// @return uint256 the end time
    function endTime(uint256 _proposalId) external view returns (uint256);

    /// @notice get the for vote count
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number of votes in favor
    function forVotes(uint256 _proposalId) external view returns (uint256);

    /// @notice get the against vote count
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number of against votes
    function againstVotes(uint256 _proposalId) external view returns (uint256);

    /// @notice get the number of abstentions
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number abstentions
    function abstentionCount(uint256 _proposalId) external view returns (uint256);

    /// @notice get the current number counting towards quorum
    /// @param _proposalId the id of the proposal
    /// @return uint256 the amount of participation
    function quorum(uint256 _proposalId) external view returns (uint256);

    /// @notice test if the address is a supervisor on the specified proposal
    /// @param _proposalId the id of the proposal
    /// @param _supervisor the address to check
    /// @return bool true if the address is a supervisor
    function isSupervisor(uint256 _proposalId, address _supervisor) external returns (bool);

    /// @notice test if address is a voter on the specified proposal
    /// @param _proposalId the id of the proposal
    /// @param _voter the address to check
    /// @return bool true if the address is a voter
    function isVoter(uint256 _proposalId, address _voter) external returns (bool);

    /// @notice test if proposal is ready or in the setup phase
    /// @param _proposalId the id of the proposal
    /// @return bool true if the proposal is marked ready
    function isFinal(uint256 _proposalId) external view returns (bool);

    /// @notice test if proposal is cancelled
    /// @param _proposalId the id of the proposal
    /// @return bool true if the proposal is marked cancelled
    function isCancel(uint256 _proposalId) external view returns (bool);

    /// @notice test if proposal is veto
    /// @param _proposalId the id of the proposal
    /// @return bool true if the proposal is marked veto
    function isVeto(uint256 _proposalId) external view returns (bool);

    /// @notice get the id of the last proposal for sender
    /// @return uint256 the id of the most recent proposal for sender
    function latestProposal(address _sender) external view returns (uint256);

    /// @notice get the vote receipt
    /// @return _shareId the share id for the vote
    /// @return _shareFor the shares cast in favor
    /// @return _votesCast the number of votes cast
    /// @return _isAbstention true if vote was an abstention
    /// @return _isUndo true if the vote was reversed
    function voteReceipt(uint256 _proposalId, uint256 shareId)
        external
        view
        returns (
            uint256 _shareId,
            uint256 _shareFor,
            uint256 _votesCast,
            bool _isAbstention,
            bool _isUndo
        );

    /// @notice get the VoterClass used for this voting store
    /// @return VoterClass the voter class for this store
    function voterClass() external view returns (VoterClass);

    /// @notice initialize a new proposal and return the id
    /// @return uint256 the id of the proposal
    function initializeProposal(address _sender) external returns (uint256);

    /// @notice indicate the proposal is ready for voting and should be frozen
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _sender original wallet for this request
    function makeFinal(uint256 _proposalId, address _sender) external;

    /// @notice cancel the proposal if it is not yet started
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _sender original wallet for this request
    function cancel(uint256 _proposalId, address _sender) external;

    /// @notice veto the specified proposal
    /// @dev supervisor is required
    /// @param _proposalId the id of the proposal
    /// @param _sender the address of the veto sender
    function veto(uint256 _proposalId, address _sender) external;

    /// @notice cast an affirmative vote for the specified share
    /// @param _proposalId the id of the proposal
    /// @param _wallet the wallet represented for the vote
    /// @param _shareId the id of the share
    /// @return uint256 the number of votes cast
    function voteForByShare(
        uint256 _proposalId,
        address _wallet,
        uint256 _shareId
    ) external returns (uint256);

    /// @notice cast an against vote for the specified share
    /// @param _proposalId the id of the proposal
    /// @param _wallet the wallet represented for the vote
    /// @param _shareId the id of the share
    /// @return uint256 the number of votes cast
    function voteAgainstByShare(
        uint256 _proposalId,
        address _wallet,
        uint256 _shareId
    ) external returns (uint256);

    /// @notice cast an abstention for the specified share
    /// @param _proposalId the id of the proposal
    /// @param _wallet the wallet represented for the vote
    /// @param _shareId the id of the share
    /// @return uint256 the number of votes cast
    function abstainForShare(
        uint256 _proposalId,
        address _wallet,
        uint256 _shareId
    ) external returns (uint256);

    /// @notice undo vote for the specified receipt
    /// @param _proposalId the id of the proposal
    /// @param _wallet the wallet represented for the vote
    /// @param _receiptId the id of the share to undo
    /// @return uint256 the number of votes cast
    function undoVoteById(
        uint256 _proposalId,
        address _wallet,
        uint256 _receiptId
    ) external returns (uint256);

    /// @notice do nothing or revert if the proposal is not valid
    /// @param _proposalId the id of the proposal
    function validOrRevert(uint256 _proposalId) external view;

    /// @notice get the maxiumum possible for the pass threshold
    /// @return uint256 the maximum value
    function maxPassThreshold() external pure returns (uint256);

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure returns (string memory);

    /// @notice return the version of this implementation
    /// @return uint32 version number
    function version() external pure returns (uint32);
}
