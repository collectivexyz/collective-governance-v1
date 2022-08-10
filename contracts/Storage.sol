// SPDX-License-Identifier: BSD-3-Clause
/*
 * Copyright 2022 collective.xyz
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
pragma solidity ^0.8.15;

import "../contracts/VoterClass.sol";
import "../contracts/VotingStrategy.sol";

/// @title Storage
/// governance storage for the Proposal struct
interface Storage {
    // event section
    event AddSupervisor(uint256 proposalId, address supervisor);
    event BurnSupervisor(uint256 proposalId, address supervisor);
    event RegisterVoter(uint256 proposalId, address voter);
    event BurnVoter(uint256 proposalId, address voter);
    event RegisterVoterClassOpenVoting(uint256 proposalId);
    event RegisterVoterClassERC721(uint256 proposalId, address token);
    event BurnVoterClass(uint256 proposalId);
    event SetRequiredParticipation(uint256 proposalId, uint256 requiredParticipation);
    event SetQuorumThreshold(uint256 proposalId, uint256 passThreshold);
    event UndoVoteEnabled(uint256 proposalId);

    event VoteCast(uint256 proposalId, address voter, uint256 totalVotesCast);
    event UndoVote(uint256 proposalId, address voter, uint256 votesUndone);
    event VoteVeto(uint256 proposalId, address supervisor);

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposalSender;
        /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
        uint256 quorumRequired;
        /// @notice Required participation yea or nea for a successful vote
        uint256 requiredParticipation;
        /// @notice The block at which voting begins
        uint256 startBlock;
        /// @notice The block at which voting ends
        uint256 endBlock;
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
        /// @notice construction phase, voting is not yet open or closed
        bool isReady;
        /// @notice this proposal allows undo votes
        bool isUndoEnabled;
        /// @notice version of strategy applied to proposal
        uint32 strategyVersion;
        /// @notice general voter class enabled for this vote
        VoterClass voterClass;
        /// @notice Strategy applied to this proposal
        VotingStrategy votingStrategy;
        /// @notice Receipts of   ballots for the entire set of voters
        mapping(address => Receipt) voteReceipt;
        /// @notice configured supervisors
        mapping(address => bool) supervisorPool;
        /// @notice whitelisted voters
        mapping(address => bool) voterPool;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice number of votes cast for
        uint256 votedFor;
        /// @notice The number of votes the voter had, which were cast
        uint256 votesCast;
    }

    function registerSupervisor(uint256 _proposalId, address _supervisor) external;

    function burnSupervisor(uint256 _proposalId, address _supervisor) external;

    function registerVoter(uint256 _proposalId, address _voter) external;

    function registerVoters(uint256 _proposalId, address[] memory _voter) external;

    function burnVoter(uint256 _proposalId, address _voter) external;

    function registerVoterClassERC721(uint256 _proposalId, address token) external;

    function registerVoterClassOpenVoting(uint256 _proposalId) external;

    function burnVoterClass(uint256 _proposalId) external;

    function setQuorumThreshold(uint256 _proposalId, uint256 _passThreshold) external;

    function setRequiredParticipation(uint256 _proposalId, uint256 _voteTally) external;

    function setVoteDelay(uint256 _proposalId, uint256 _voteDelay) external;

    function setRequiredVoteDuration(uint256 _proposalId, uint256 _voteDuration) external;

    function makeReady(uint256 _proposalId) external;

    function isReady(uint256 _proposalId) external returns (bool);
}
