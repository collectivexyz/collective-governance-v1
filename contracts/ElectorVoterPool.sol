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
import "./VoterClass.sol";
import "./VoterClassNullObject.sol";
import "./VotingStrategy.sol";

/// @title ElectorVoterPool

// GovernorBravoDelegate.sol source code Copyright 2020 Compound Labs, Inc. licensed under the BSD-3-Clause license.
// NounsDAOLogicV1.sol source code Copyright 2020 Nounders DAO. licensed under the BSD-3-Clause license.
// This source code developed by Collective.xyz, Copyright 2022.

// a proposal is subject to approval by an elector voter pool, a specific group of supervisors has the authority to add and remove voters, to open and close voting
// and to veto the result of the vote as in the case of a failure of the election design

// modification to the vote and supervisor pools is only allowed prior to the opening of voting
// 'affirmative' vote must be cast by calling voteFor
// 'abstention' or 'negative' vote incurs no gas fees and every registered voter is default negative

// measure is considered passed when the threshold voter count is achieved out of the current voting pool

contract ElectorVoterPool is GovernanceStorage, VotingStrategy {
    /// @notice contract name
    string public constant name = "collective.xyz governance contract";
    uint32 public constant VERSION_1 = 1;
    uint32 public constant version = VERSION_1;

    modifier requireStrategyVersion(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(address(this) == address(proposal.votingStrategy), "Strategy not valid for this proposalId");
        _;
    }

    modifier requireProposalSender(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.proposalSender == msg.sender, "Not contract owner");
        _;
    }

    modifier requireElectorSupervisor(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.supervisorPool[msg.sender] == true, "Operation requires elector supervisor");
        _;
    }

    modifier requireVoter(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.voterPool[msg.sender] == true || proposal.voterClass.isVoter(msg.sender), "Voter required");
        _;
    }

    modifier requireVotingOpen(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.isVotingOpen, "Voting is closed.");
        _;
    }

    modifier requireVotingClosed(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(!proposal.isVotingOpen && !proposal.isVotingPrelim && !proposal.isVeto, "Voting is not closed.");
        _;
    }

    modifier requireVotingPrelim(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.isVotingPrelim && !proposal.isVotingOpen, "Vote not modifiable.");
        _;
    }

    modifier requireUndo(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.isUndoEnabled, "Undo not enabled for this vote");
        _;
    }

    modifier requireInitializedProposal(uint256 _proposalId) {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.id == _proposalId && _proposalId != 0, "Not a valid proposal");
        _;
    }

    /// @notice add a vote superviser to the supervisor pool with rights to add or remove voters prior to start of voting, also right to veto the outcome after voting is closed
    function registerSupervisor(uint256 _proposalId, address _supervisor)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireProposalSender(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        if (proposal.supervisorPool[_supervisor] == false) {
            proposal.supervisorPool[_supervisor] = true;
            emit AddSupervisor(_supervisor);
        }
    }

    /// @notice remove the supervisor from the supervisor pool suspending their rights to modify the election
    function burnSupervisor(uint256 _proposalId, address _supervisor)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireProposalSender(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        if (proposal.supervisorPool[_supervisor] == true) {
            proposal.supervisorPool[_supervisor] = false;
            emit BurnSupervisor(_supervisor);
        }
    }

    /// @notice enable vote undo feature
    function enableUndoVote(uint256 _proposalId)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        proposal.isUndoEnabled = true;
        emit UndoVoteEnabled();
    }

    /// @notice register a voter on this measure
    function registerVoter(uint256 _proposalId, address _voter)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        if (proposal.voterPool[_voter] == false) {
            proposal.voterPool[_voter] = true;
            emit RegisterVoter(_voter);
        }
    }

    /// @notice register a list of voters on this measure
    function registerVoters(uint256 _proposalId, address[] memory _voter)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        uint256 addedCount = 0;
        for (uint256 i = 0; i < _voter.length; i++) {
            if (proposal.voterPool[_voter[i]] == false) {
                proposal.voterPool[_voter[i]] = true;
                emit RegisterVoter(_voter[i]);
            }
            addedCount++;
        }
    }

    /// @notice burn the specified voter, removing their rights to participate in the election
    function burnVoter(uint256 _proposalId, address _voter)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        if (proposal.voterPool[_voter] == true) {
            proposal.voterPool[_voter] = false;
            emit BurnVoter(_voter);
        }
    }

    /// @notice register a voting class for this measure
    function registerVoterClass(uint256 _proposalId, VoterClass _class)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        proposal.voterClass = _class;
        emit RegisterVoterClass();
    }

    /// @notice burn voter class
    function burnVoterClass(uint256 _proposalId)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        proposal.voterClass = new VoterClassNullObject();
        emit BurnVoterClass();
    }

    function setRequiredParticipation(uint256 _proposalId, uint256 _voteTally)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        proposal.requiredParticipation = _voteTally;
        emit SetRequiredParticipation(_voteTally);
    }

    /// @notice establish the pass threshold for this measure
    function setQuorumThreshold(uint256 _proposalId, uint256 _passThreshold)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        proposal.quorumRequired = _passThreshold;
        emit SetQuorumThreshold(_passThreshold);
    }

    /// @notice allow voting
    function openVoting(uint256 _proposalId)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingPrelim(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        require(proposal.quorumRequired < GovernanceStorage.MAXIMUM_PASS_THRESHOLD, "Quorum must be set prior to opening vote");
        proposal.isVotingOpen = true;
        proposal.isVotingPrelim = false;
        emit VotingOpen();
    }

    /// @notice forbid any further voting
    function endVoting(uint256 _proposalId)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingOpen(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        proposal.isVotingOpen = false;
        emit VotingClosed();
    }

    // @notice cast an affirmative vote for the measure
    function voteFor(uint256 _proposalId)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireVoter(_proposalId)
        requireVotingOpen(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        uint256 votesAvailable = proposal.voterClass.votesAvailable(msg.sender);
        GovernanceStorage.Receipt storage receipt = proposal.voteReceipt[msg.sender];
        if (receipt.votesCast < votesAvailable) {
            uint256 remainingVotes = votesAvailable - receipt.votesCast;
            receipt.votesCast += remainingVotes;
            receipt.votedFor += remainingVotes;
            proposal.forVotes += remainingVotes;
            emit VoteCast(msg.sender, remainingVotes);
        } else {
            revert("Vote cast previously on this measure");
        }
    }

    // @notice undo any previous vote
    function undoVote(uint256 _proposalId)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireUndo(_proposalId)
        requireVoter(_proposalId)
        requireVotingOpen(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        GovernanceStorage.Receipt storage receipt = proposal.voteReceipt[msg.sender];
        if (receipt.votedFor > 0) {
            uint256 undoVotes = receipt.votedFor;
            receipt.votedFor -= undoVotes;
            receipt.votesCast -= undoVotes;
            proposal.forVotes -= undoVotes;
        } else {
            revert("Nothing to undo");
        }
    }

    /// @notice veto the current measure
    function veto(uint256 _proposalId)
        public
        requireInitializedProposal(_proposalId)
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingOpen(_proposalId)
    {
        GovernanceStorage.Proposal storage proposal = GovernanceStorage.proposalMap[_proposalId];
        if (!proposal.isVeto) {
            proposal.isVeto = true;
            emit VoteVeto(msg.sender);
        } else {
            revert("Double veto");
        }
    }

    function setVoteDelay(
        uint256, /* _proposalId */
        uint256 /*_voteDelay*/
    ) public pure {
        revert("Timed voting not implemented");
    }

    function setRequiredVoteDuration(
        uint256, /* _proposalId */
        uint256 /* _voteDuration */
    ) public pure {
        revert("Timed voting not implemented");
    }

    function setRequiredVoteParticipation(
        uint256, /* _proposalId */
        uint256 /* _voteTally */
    ) public pure {
        revert("Minimum vote not implemented");
    }

    function voteAgainst(
        uint256 /* _proposalId */
    ) public pure {
        revert("Vote against not implemented");
    }

    function abstainFromVote(
        uint256 /* _proposalId */
    ) public pure {
        revert("Abstention not implemented");
    }

    /// @notice get the result of the measure pass or failed
    function getVoteSucceeded(uint256 _proposalId)
        public
        view
        requireInitializedProposal(_proposalId)
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
