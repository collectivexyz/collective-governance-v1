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

import "../contracts/Storage.sol";
import "../contracts/VoterClassERC721.sol";
import "../contracts/VoterClassOpenVote.sol";

contract GovernanceStorage is Storage {
    /// @notice contract name
    string public constant name = "collective.xyz governance storage";
    uint32 public constant VERSION_1 = 1;

    uint256 public constant MAXIMUM_PASS_THRESHOLD = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 public constant MINIMUM_VOTE_DURATION = 1;

    /// @notice global list of proposed issues by id
    mapping(uint256 => Proposal) public proposalMap;

    /// @notice The total number of proposals
    uint256 internal _proposalCount;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) internal _latestProposalId;

    modifier requireValidAddress(address _wallet) {
        require(_wallet != address(0), "Not a valid wallet");
        _;
    }

    modifier requireValidProposal(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(
            _proposalId > 0 && _proposalId <= _proposalCount && proposal.id == _proposalId && !proposal.isVeto,
            "Not a valid proposal"
        );
        _;
    }

    modifier requireProposalSender(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.proposalSender == msg.sender, "Not proposal creator");
        _;
    }

    modifier requireElectorSupervisor(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.supervisorPool[msg.sender], "Operation requires elector supervisor");
        _;
    }

    modifier requireVoter(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        bool isRegistered = proposal.voterPool[msg.sender];
        bool isPartOfClass = proposal.voterClass.isVoter(msg.sender);
        require(isRegistered || isPartOfClass, "Voter required");
        _;
    }

    modifier requireVotingNotReady(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(!proposal.isReady, "Vote not modifiable");
        _;
    }

    modifier requireVotingReady(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.isReady, "Vote not ready");
        _;
    }

    modifier requireVotingActive(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.startBlock >= block.number && proposal.endBlock > block.number, "Vote not active");
        _;
    }

    modifier requireUndo(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.isUndoEnabled, "Undo not enabled for this vote");
        _;
    }

    /// @notice initialize a proposal and return the id
    function _initializeProposal(address _strategy) external returns (uint256) {
        uint256 latestProposalId = _latestProposalId[msg.sender];
        if (latestProposalId != 0) {
            Proposal storage latestProposal = proposalMap[latestProposalId];
            require(!latestProposal.isReady, "Too many proposals in process");
        }
        _proposalCount++;
        uint256 proposalId = _proposalCount;
        _latestProposalId[msg.sender] = proposalId;

        // proposal
        Proposal storage proposal = proposalMap[proposalId];
        proposal.id = proposalId;
        proposal.proposalSender = msg.sender;
        proposal.quorumRequired = MAXIMUM_PASS_THRESHOLD;
        proposal.requiredParticipation = 0;
        proposal.voteDelay = 0;
        proposal.voteDuration = MINIMUM_VOTE_DURATION;
        proposal.startBlock = 0;
        proposal.endBlock = 0;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.abstentionCount = 0;
        proposal.isVeto = false;
        proposal.isReady = false;
        proposal.isUndoEnabled = false;
        proposal.voterClass = new VoterClassNullObject();
        proposal.voteStrategy = _strategy;

        return proposalId;
    }

    /// @notice add a vote superviser to the supervisor pool with rights to add or remove voters prior to start of voting, also right to veto the outcome after voting is closed
    function registerSupervisor(uint256 _proposalId, address _supervisor)
        public
        requireValidAddress(_supervisor)
        requireValidProposal(_proposalId)
        requireProposalSender(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        if (!proposal.supervisorPool[_supervisor]) {
            proposal.supervisorPool[_supervisor] = true;
            emit AddSupervisor(_proposalId, _supervisor);
        }
    }

    /// @notice remove the supervisor from the supervisor pool suspending their rights to modify the election
    function burnSupervisor(uint256 _proposalId, address _supervisor)
        public
        requireValidAddress(_supervisor)
        requireValidProposal(_proposalId)
        requireProposalSender(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.supervisorPool[_supervisor]) {
            proposal.supervisorPool[_supervisor] = false;
            emit BurnSupervisor(_proposalId, _supervisor);
        }
    }

    /// @notice enable vote undo feature
    function enableUndoVote(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.isUndoEnabled = true;
        emit UndoVoteEnabled(_proposalId);
    }

    /// @notice register a voter on this measure
    function registerVoter(uint256 _proposalId, address _voter)
        public
        requireValidAddress(_voter)
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        if (!proposal.voterPool[_voter]) {
            proposal.voterPool[_voter] = true;
            emit RegisterVoter(_proposalId, _voter);
        } else {
            revert("Voter registered previously");
        }
    }

    /// @notice register a list of voters on this measure
    function registerVoters(uint256 _proposalId, address[] memory _voter)
        public
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 addedCount = 0;
        for (uint256 i = 0; i < _voter.length; i++) {
            if (_voter[i] != address(0) && !proposal.voterPool[_voter[i]]) {
                proposal.voterPool[_voter[i]] = true;
                emit RegisterVoter(_proposalId, _voter[i]);
            }
            addedCount++;
        }
    }

    /// @notice burn the specified voter, removing their rights to participate in the election
    function burnVoter(uint256 _proposalId, address _voter)
        public
        requireValidAddress(_voter)
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.voterPool[_voter]) {
            proposal.voterPool[_voter] = false;
            emit BurnVoter(_proposalId, _voter);
        }
    }

    /// @notice register a voting class for this measure
    function registerVoterClassERC721(uint256 _proposalId, address _token)
        public
        requireValidAddress(_token)
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voterClass = new VoterClassERC721(_token);
        emit RegisterVoterClassERC721(_proposalId, _token);
    }

    /// @notice register a voting class for this measure
    function registerVoterClassOpenVote(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voterClass = new VoterClassOpenVote();
        emit RegisterVoterClassOpenVote(_proposalId);
    }

    /// @notice burn voter class
    function burnVoterClass(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voterClass = new VoterClassNullObject();
        emit BurnVoterClass(_proposalId);
    }

    function setRequiredParticipation(uint256 _proposalId, uint256 _voteTally)
        public
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.requiredParticipation = _voteTally;
        emit SetRequiredParticipation(_proposalId, _voteTally);
    }

    /// @notice establish the pass threshold for this measure
    function setQuorumThreshold(uint256 _proposalId, uint256 _passThreshold)
        public
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.quorumRequired = _passThreshold;
        emit SetQuorumThreshold(_proposalId, _passThreshold);
    }

    function setVoteDelay(uint256 _proposalId, uint256 _voteDelay)
        public
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voteDelay = _voteDelay;
    }

    function setRequiredVoteDuration(uint256 _proposalId, uint256 _voteDuration)
        public
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        require(_voteDuration >= MINIMUM_VOTE_DURATION, "Voting duration is not valid");
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voteDuration = _voteDuration;
    }

    function setRequiredVoteParticipation(uint256 _proposalId, uint256 _voteTally)
        public
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.requiredParticipation = _voteTally;
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
        requireValidAddress(_supervisor)
        requireValidProposal(_proposalId)
        returns (bool)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.supervisorPool[_supervisor];
    }

    function isVoter(uint256 _proposalId, address _voter)
        external
        view
        requireValidAddress(_voter)
        requireValidProposal(_proposalId)
        returns (bool)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voterPool[_voter] || proposal.voterClass.isVoter(_voter);
    }

    function isVeto(uint256 _proposalId) external view returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_proposalId > 0 && _proposalId <= _proposalCount, "Unknown proposal");
        return proposal.isVeto;
    }

    function makeReady(uint256 _proposalId) external requireElectorSupervisor(_proposalId) requireVotingNotReady(_proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.isReady = true;
        proposal.startBlock = block.number + proposal.voteDelay;
        proposal.endBlock = proposal.startBlock + proposal.voteDuration;
        emit VoteReady(_proposalId, proposal.startBlock, proposal.endBlock);
    }

    /// @notice true if proposal is in setup phase
    function isReady(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.isReady;
    }

    /// @notice veto the current measure
    function _veto(uint256 _proposalId) public requireValidProposal(_proposalId) requireElectorSupervisor(_proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (!proposal.isVeto) {
            proposal.isVeto = true;
            emit VoteVeto(_proposalId, msg.sender);
        } else {
            revert("Double veto");
        }
    }

    /* @notice cast vote affirmative */
    function _castVoteFor(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireVoter(_proposalId)
        requireVotingActive(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 votesAvailable = 1;
        if (proposal.voterClass.isVoter(msg.sender)) {
            votesAvailable = proposal.voterClass.votesAvailable(msg.sender);
        }
        Receipt storage receipt = proposal.voteReceipt[msg.sender];
        if (receipt.votesCast < votesAvailable) {
            uint256 remainingVotes = votesAvailable - receipt.votesCast;
            receipt.votesCast += remainingVotes;
            receipt.votedFor += remainingVotes;
            proposal.forVotes += remainingVotes;
            emit VoteCast(_proposalId, msg.sender, remainingVotes);
        } else {
            revert("Vote cast previously on this measure");
        }
    }

    /* @notice cast vote negative */
    function _castVoteAgainst(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireVoter(_proposalId)
        requireVotingActive(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 votesAvailable = 1;
        if (proposal.voterClass.isVoter(msg.sender)) {
            votesAvailable = proposal.voterClass.votesAvailable(msg.sender);
        }
        Receipt storage receipt = proposal.voteReceipt[msg.sender];
        if (receipt.votesCast < votesAvailable) {
            uint256 remainingVotes = votesAvailable - receipt.votesCast;
            receipt.votesCast += remainingVotes;
            proposal.againstVotes += remainingVotes;
            emit VoteCast(_proposalId, msg.sender, remainingVotes);
        } else {
            revert("Vote cast previously on this measure");
        }
    }

    /* @notice cast vote Undo */
    function _castVoteUndo(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireVoter(_proposalId)
        requireUndo(_proposalId)
        requireVotingActive(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt storage receipt = proposal.voteReceipt[msg.sender];
        if (receipt.votedFor > 0) {
            uint256 undoVotes = receipt.votedFor;
            receipt.votedFor -= undoVotes;
            receipt.votesCast -= undoVotes;
            proposal.forVotes -= undoVotes;
            emit UndoVote(_proposalId, msg.sender, undoVotes);
        } else {
            revert("Nothing to undo");
        }
    }

    /* @notice mark abstention */
    function _abstainFromVote(uint256 _proposalId)
        public
        requireValidProposal(_proposalId)
        requireVoter(_proposalId)
        requireVotingActive(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 votesAvailable = 1;
        if (proposal.voterClass.isVoter(msg.sender)) {
            votesAvailable = proposal.voterClass.votesAvailable(msg.sender);
        }
        Receipt storage receipt = proposal.voteReceipt[msg.sender];
        if (receipt.votesCast < votesAvailable) {
            uint256 remainingVotes = votesAvailable - receipt.votesCast;
            receipt.votesCast += remainingVotes;
            proposal.abstentionCount += remainingVotes;
            emit VoteCast(_proposalId, msg.sender, remainingVotes);
        } else {
            revert("Vote cast previously on this measure");
        }
    }

    function voteDelay(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voteDelay;
    }

    function voteDuration(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voteDuration;
    }

    function startBlock(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.startBlock;
    }

    function endBlock(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.endBlock;
    }

    function voteStrategy(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (address) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voteStrategy;
    }

    function version() public pure virtual returns (uint32) {
        return VERSION_1;
    }

    function _validOrRevert(uint256 _proposalId)
        external
        view
        requireValidProposal(_proposalId)
    // solium-disable-next-line no-empty-blocks
    {

    }

    function _maxPassThreshold() external pure returns (uint256) {
        return MAXIMUM_PASS_THRESHOLD;
    }
}
