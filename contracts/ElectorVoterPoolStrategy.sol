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

import "./GovernanceStorage.sol";
import "./VotingStrategy.sol";

/// @title ElectorVoterPoolStrategy

// GovernorBravoDelegate.sol source code Copyright 2020 Compound Labs, Inc. licensed under the BSD-3-Clause license.
// NounsDAOLogicV1.sol source code Copyright 2020 Nounders DAO. licensed under the BSD-3-Clause license.
// This source code developed by Collective.xyz, Copyright 2022.

// a proposal is subject to approval by an elector voter pool, a specific group of supervisors has the authority to add and remove voters, to open and close voting
// and to veto the result of the vote as in the case of a failure of the election design

// modification to the vote and supervisor pools is only allowed prior to the opening of voting
// 'affirmative' vote must be cast by calling voteFor
// 'abstention' or 'negative' vote incurs no gas fees and every registered voter is default negative

// measure is considered passed when the threshold voter count is achieved out of the current voting pool

contract ElectorVoterPoolStrategy is GovernanceStorage, VotingStrategy {
    /// @notice contract name
    string public constant name = "collective.xyz governance contract";
    uint32 public constant VERSION_1 = 1;
    uint32 public constant version = VERSION_1;

    /// @notice voting is open or not
    mapping(uint256 => bool) isVotingOpenByProposalId;

    modifier requireStrategyVersion(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(address(this) == address(proposal.votingStrategy), "Strategy not valid for this proposalId");
        _;
    }

    modifier requireVotingOpen(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.isReady && isVotingOpenByProposalId[_proposalId] && !proposal.isVeto, "Voting is closed.");
        _;
    }

    modifier requireVotingClosed(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.isReady && !isVotingOpenByProposalId[_proposalId] && !proposal.isVeto, "Voting is not closed.");
        _;
    }

    /// @notice allow voting
    function openVoting(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingReady(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.quorumRequired < GovernanceStorage.MAXIMUM_PASS_THRESHOLD, "Quorum must be set prior to opening vote");
        if (!isVotingOpenByProposalId[_proposalId]) {
            isVotingOpenByProposalId[_proposalId] = true;
            emit VotingOpen(_proposalId);
        } else {
            revert("Already open.");
        }
    }

    function isOpen(uint256 _proposalId)
        public
        view
        requireValidProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        returns (bool)
    {
        return isVotingOpenByProposalId[_proposalId];
    }

    /// @notice forbid any further voting
    function endVoting(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingOpen(_proposalId)
    {
        isVotingOpenByProposalId[_proposalId] = false;
        emit VotingClosed(_proposalId);
    }

    /// @notice veto the current measure
    function veto(uint256 _proposalId) public requireStrategyVersion(_proposalId) requireVotingOpen(_proposalId) {
        _veto(_proposalId);
    }

    // @notice cast an affirmative vote for the measure
    function voteFor(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireVoter(_proposalId)
        requireVotingOpen(_proposalId)
    {
        _castVoteFor(_proposalId);
    }

    // @notice undo any previous vote
    function undoVote(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireVoter(_proposalId)
        requireVotingOpen(_proposalId)
    {
        _castVoteUndo(_proposalId);
    }

    function voteAgainst(uint256 _proposalId) public requireStrategyVersion(_proposalId) requireVotingOpen(_proposalId) {
        _castVoteAgainst(_proposalId);
    }

    function abstainFromVote(uint256 _proposalId) public requireStrategyVersion(_proposalId) requireVotingOpen(_proposalId) {
        _abstainFromVote(_proposalId);
    }

    /// @notice get the result of the measure pass or failed
    function getVoteSucceeded(uint256 _proposalId)
        public
        view
        requireValidProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireVotingClosed(_proposalId)
        returns (bool)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        uint256 totalVotesCast = proposal.forVotes + proposal.againstVotes + proposal.abstentionCount;
        require(totalVotesCast >= proposal.requiredParticipation, "Not enough participants");
        return proposal.forVotes >= proposal.quorumRequired;
    }
}
