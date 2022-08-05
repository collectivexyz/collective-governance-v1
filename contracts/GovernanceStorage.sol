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

import "./VotingStrategy.sol";

contract GovernanceStorage {
    uint256 public constant MAXIMUM_PASS_THRESHOLD = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

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
        bool executed;
        /// @notice voting is open or not
        bool isVotingOpen;
        /// @notice voting is not yet open or closed
        bool isVotingPrelim;
        /// @notice this proposal allows undo votes
        bool isUndoEnabled;
        /// @notice version of strategy applied to proposal
        uint32 strategyVersion;
        /// @notice general voter class enabled for this vote
        VoterClass voterClass;
        /// @notice Strategy applied to this proposal
        VotingStrategy votingStrategy;
        /// @notice Receipts of ballots for the entire set of voters
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

    /// @notice global list of proposed issues by id
    mapping(uint256 => Proposal) public proposalMap;

    /// @notice The total number of proposals
    uint256 internal proposalCount;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) internal _latestProposalId;

    modifier requireValidProposal(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_proposalId > 0 && _proposalId <= proposalCount, "Not a valid proposal");
        _;
    }

    /// @notice return the newly initialized proposal id
    function initializeProposal(VotingStrategy _strategy) external returns (uint256) {
        uint256 latestProposalId = _latestProposalId[msg.sender];
        if (latestProposalId != 0) {
            require(isDead(latestProposalId), "Too many active proposals");
        }
        proposalCount++;
        uint256 proposalId = proposalCount;
        _latestProposalId[msg.sender] = proposalId;
        Proposal storage proposal = proposalMap[proposalId];

        proposal.id = proposalId;
        proposal.proposalSender = msg.sender;
        proposal.quorumRequired = MAXIMUM_PASS_THRESHOLD;
        proposal.requiredParticipation = 0;
        proposal.startBlock = 0;
        proposal.endBlock = 0;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.abstentionCount = 0;
        proposal.executed = false;
        proposal.isVeto = false;
        proposal.isVotingOpen = false;
        proposal.isVotingPrelim = true;
        proposal.isUndoEnabled = false;
        proposal.voterClass = new VoterClassNullObject();
        proposal.strategyVersion = _strategy.version();
        proposal.votingStrategy = _strategy;

        return proposalId;
    }

    /// @notice true if proposal has concluded
    function isDead(uint256 _proposalId) public view requireValidProposal(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.isVeto || !(proposal.isVotingPrelim || proposal.isVotingOpen);
    }

    function getSender(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (address) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.proposalSender;
    }

    function quorumRequired(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.quorumRequired;
    }

    function requiredParticipation(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.requiredParticipation;
    }

    function forVotes(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.forVotes;
    }

    function againstVotes(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.againstVotes;
    }

    function abstentionCount(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.abstentionCount;
    }

    function totalParticipation(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.forVotes + proposal.againstVotes + proposal.abstentionCount;
    }

    function isSupervisor(uint256 _proposalId, address _supervisor)
        external
        view
        requireValidProposal(_proposalId)
        returns (bool)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.supervisorPool[_supervisor];
    }

    function isVoter(uint256 _proposalId, address _voter) external view requireValidProposal(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voterPool[_voter] || proposal.voterClass.isVoter(_voter);
    }

    function isVeto(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.isVeto;
    }
}
