// SPDX-License-Identifier: BSD-3-Clause
/*
 * Copyright 2022 collective.xyz
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
pragma solidity ^0.8.15;

import "../contracts/Storage.sol";
import "../contracts/VoterClassERC721.sol";
import "../contracts/VoterClassOpenVote.sol";
import "../contracts/VoterClassVoterPool.sol";

contract GovernanceStorage is Storage {
    /// @notice contract name
    string public constant name = "collective.xyz governance storage";
    uint32 public constant VERSION_1 = 1;

    uint256 public constant MAXIMUM_QUORUM = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 public constant MINIMUM_VOTE_DURATION = 1;

    /// @notice global list of proposed issues by id
    mapping(uint256 => Proposal) public proposalMap;

    /// @notice The total number of proposals
    uint256 internal _proposalCount;

    /// @notice only the peer contract may modify the vote
    address private _cognate;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) internal _latestProposalId;

    constructor() {
        _cognate = msg.sender;
    }

    modifier requireValidAddress(address _wallet) {
        require(_wallet != address(0), "Not a valid wallet");
        _;
    }

    modifier requireValidProposal(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_proposalId > 0 && _proposalId <= _proposalCount && proposal.id == _proposalId, "Invalid proposal");
        _;
    }

    modifier requireVoteCast(uint256 _proposalId, uint256 _receiptId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_receiptId > 0, "Receipt id is not valid");
        Receipt storage receipt = proposal.voteReceipt[_receiptId];
        require(receipt.shareId == _receiptId, "No vote cast");
        require(receipt.votesCast > 0 && !receipt.abstention && !receipt.undoCast, "No affirmative vote");
        _;
    }

    modifier requireReceiptForWallet(
        uint256 _proposalId,
        uint256 _receiptId,
        address _wallet
    ) {
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt storage receipt = proposal.voteReceipt[_receiptId];
        require(receipt.wallet == _wallet, "Not voter");
        _;
    }

    modifier requireValidReceipt(uint256 _proposalId, uint256 _receiptId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_receiptId > 0, "Receipt id is not valid");
        Receipt storage receipt = proposal.voteReceipt[_receiptId];
        require(receipt.shareId > 0, "Receipt not initialized");
        _;
    }

    modifier requireShareAvailable(uint256 _proposalId, uint256 _shareId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_shareId > 0, "Share id is not valid");
        Receipt storage receipt = proposal.voteReceipt[_shareId];
        require(receipt.votesCast == 0 && !receipt.abstention && !receipt.undoCast, "Already voted");
        _;
    }

    modifier requireProposalSender(uint256 _proposalId, address _sender) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.proposalSender == _sender, "Not proposal creator");
        _;
    }

    modifier requireElectorSupervisor(uint256 _proposalId, address _sender) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.supervisorPool[_sender], "Operation requires supervisor");
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
        require(proposal.startBlock <= block.number && proposal.endBlock > block.number, "Vote not active");
        _;
    }

    modifier requireUndo(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.isUndoEnabled, "Undo not enabled");
        _;
    }

    modifier requireCognate() {
        require(msg.sender == _cognate, "Not permitted");
        _;
    }

    /// @notice initialize a proposal and return the id
    function initializeProposal(address _sender) external requireCognate returns (uint256) {
        uint256 latestProposalId = _latestProposalId[_sender];
        if (latestProposalId != 0) {
            Proposal storage latestProposal = proposalMap[latestProposalId];
            require(!latestProposal.isReady, "Too many proposals in process");
        }
        _proposalCount++;
        uint256 proposalId = _proposalCount;
        _latestProposalId[_sender] = proposalId;

        // proposal
        Proposal storage proposal = proposalMap[proposalId];
        proposal.id = proposalId;
        proposal.proposalSender = _sender;
        proposal.quorumRequired = MAXIMUM_QUORUM;
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

        emit InitializeProposal(proposalId, _sender);
        return proposalId;
    }

    /// @notice add a vote superviser to the supervisor pool with rights to add or remove voters prior to start of voting, also right to veto the outcome after voting is closed
    function registerSupervisor(
        uint256 _proposalId,
        address _supervisor,
        address _sender
    )
        public
        requireCognate
        requireValidAddress(_supervisor)
        requireValidProposal(_proposalId)
        requireProposalSender(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        if (!proposal.supervisorPool[_supervisor]) {
            proposal.supervisorPool[_supervisor] = true;
            emit AddSupervisor(_proposalId, _supervisor);
        }
    }

    /// @notice remove the supervisor from the supervisor pool suspending their rights to modify the election
    function burnSupervisor(
        uint256 _proposalId,
        address _supervisor,
        address _sender
    )
        public
        requireCognate
        requireValidAddress(_supervisor)
        requireValidProposal(_proposalId)
        requireProposalSender(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.supervisorPool[_supervisor]) {
            proposal.supervisorPool[_supervisor] = false;
            emit BurnSupervisor(_proposalId, _supervisor);
        }
    }

    /// @notice enable vote undo feature
    function enableUndoVote(uint256 _proposalId, address _sender)
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.isUndoEnabled = true;
        emit UndoVoteEnabled(_proposalId);
    }

    /// @notice register a voter on this measure
    function registerVoter(
        uint256 _proposalId,
        address _voter,
        address _sender
    )
        public
        requireCognate
        requireValidAddress(_voter)
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        VoterClassVoterPool _class = VoterClassVoterPool(address(proposal.voterClass));
        _class.addVoter(_voter);
        emit RegisterVoter(_proposalId, _voter);
    }

    /// @notice register a list of voters on this measure
    function registerVoters(
        uint256 _proposalId,
        address[] memory _voter,
        address _sender
    )
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        VoterClassVoterPool _class = VoterClassVoterPool(address(proposal.voterClass));
        require(address(_class) != address(0x0), "Voter pool required");
        uint256 addedCount = 0;
        for (uint256 i = 0; i < _voter.length; i++) {
            if (_voter[i] != address(0)) {
                _class.addVoter(_voter[i]);
                emit RegisterVoter(_proposalId, _voter[i]);
            }
            addedCount++;
        }
    }

    /// @notice burn the specified voter, removing their rights to participate in the election
    function burnVoter(
        uint256 _proposalId,
        address _voter,
        address _sender
    )
        public
        requireCognate
        requireValidAddress(_voter)
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        VoterClassVoterPool _class = VoterClassVoterPool(address(proposal.voterClass));
        _class.removeVoter(_voter);
        emit BurnVoter(_proposalId, _voter);
    }

    function registerVoterClassVoterPool(uint256 _proposalId, address _sender)
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voterClass = new VoterClassVoterPool(1);
        emit RegisterVoterClassVoterPool(_proposalId);
    }

    /// @notice register a voting class for this measure
    function registerVoterClassERC721(
        uint256 _proposalId,
        address _token,
        address _sender
    )
        public
        requireCognate
        requireValidAddress(_token)
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voterClass = new VoterClassERC721(_token, 1);
        emit RegisterVoterClassERC721(_proposalId, _token);
    }

    /// @notice register a voting class for this measure
    function registerVoterClassOpenVote(uint256 _proposalId, address _sender)
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voterClass = new VoterClassOpenVote(1);
        emit RegisterVoterClassOpenVote(_proposalId);
    }

    /// @notice burn voter class
    function burnVoterClass(uint256 _proposalId, address _sender)
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voterClass = new VoterClassNullObject();
        emit BurnVoterClass(_proposalId);
    }

    /// @notice establish the pass threshold for this measure
    function setQuorumThreshold(
        uint256 _proposalId,
        uint256 _passThreshold,
        address _sender
    )
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.quorumRequired = _passThreshold;
        emit SetQuorumThreshold(_proposalId, _passThreshold);
    }

    function setVoteDelay(
        uint256 _proposalId,
        uint256 _voteDelay,
        address _sender
    )
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voteDelay = _voteDelay;
    }

    function setRequiredVoteDuration(
        uint256 _proposalId,
        uint256 _voteDuration,
        address _sender
    )
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        require(_voteDuration >= MINIMUM_VOTE_DURATION, "Voting duration is not valid");
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voteDuration = _voteDuration;
    }

    function getSender(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (address) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.proposalSender;
    }

    function quorumRequired(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.quorumRequired;
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

    function quorum(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        return this.forVotes(_proposalId) + this.againstVotes(_proposalId) + this.abstentionCount(_proposalId);
    }

    function voterClass(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (VoterClass) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voterClass;
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
        return proposal.voterClass.isVoter(_voter);
    }

    function isVeto(uint256 _proposalId) external view returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_proposalId > 0 && _proposalId <= _proposalCount, "Unknown proposal");
        return proposal.isVeto;
    }

    function makeReady(uint256 _proposalId, address _sender)
        external
        requireCognate
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
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

    function voteReceipt(uint256 _proposalId, uint256 _shareId)
        external
        view
        requireValidProposal(_proposalId)
        requireValidReceipt(_proposalId, _shareId)
        returns (
            uint256,
            uint256,
            uint256,
            bool,
            bool
        )
    {
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt storage receipt = proposal.voteReceipt[_shareId];
        return (receipt.shareId, receipt.shareFor, receipt.votesCast, receipt.abstention, receipt.undoCast);
    }

    function version() public pure virtual returns (uint32) {
        return VERSION_1;
    }

    function validOrRevert(uint256 _proposalId)
        external
        view
        requireCognate
        requireValidProposal(_proposalId)
    // solium-disable-next-line no-empty-blocks
    {

    }

    function maxPassThreshold() external pure returns (uint256) {
        return MAXIMUM_QUORUM;
    }

    /// @notice veto the current measure
    function veto(uint256 _proposalId, address _sender)
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        if (!proposal.isVeto) {
            proposal.isVeto = true;
            emit VoteVeto(_proposalId, msg.sender);
        } else {
            revert("Already vetoed");
        }
    }

    function voteForByShare(
        uint256 _proposalId,
        address _wallet,
        uint256 _shareId
    )
        external
        requireCognate
        requireValidProposal(_proposalId)
        requireShareAvailable(_proposalId, _shareId)
        requireVotingActive(_proposalId)
        returns (uint256)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 _shareCount = proposal.voterClass.confirm(_wallet, _shareId);
        require(_shareCount > 0, "Share not available");
        Receipt storage receipt = proposal.voteReceipt[_shareId];
        receipt.wallet = _wallet;
        receipt.shareId = _shareId;
        receipt.votesCast = _shareCount;
        receipt.shareFor = _shareCount;
        proposal.forVotes += _shareCount;
        emit VoteCast(_proposalId, _wallet, _shareId, _shareCount);
        return _shareCount;
    }

    function voteAgainstByShare(
        uint256 _proposalId,
        address _wallet,
        uint256 _shareId
    )
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireShareAvailable(_proposalId, _shareId)
        requireVotingActive(_proposalId)
        returns (uint256)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 _shareCount = proposal.voterClass.confirm(_wallet, _shareId);
        require(_shareCount > 0, "Share not available");
        Receipt storage receipt = proposal.voteReceipt[_shareId];
        receipt.wallet = _wallet;
        receipt.shareId = _shareId;
        receipt.votesCast = _shareCount;
        receipt.abstention = false;
        proposal.againstVotes += _shareCount;
        emit VoteCast(_proposalId, _wallet, _shareId, _shareCount);
        return _shareCount;
    }

    function abstainForShare(
        uint256 _proposalId,
        address _wallet,
        uint256 _shareId
    ) public requireCognate requireValidProposal(_proposalId) requireVotingActive(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 _shareCount = proposal.voterClass.confirm(_wallet, _shareId);
        require(_shareCount > 0, "Share not available");
        Receipt storage receipt = proposal.voteReceipt[_shareId];
        receipt.wallet = _wallet;
        receipt.shareId = _shareId;
        receipt.votesCast = _shareCount;
        receipt.abstention = true;
        proposal.abstentionCount += _shareCount;
        emit VoteCast(_proposalId, _wallet, _shareId, _shareCount);
        return _shareCount;
    }

    function undoVoteById(
        uint256 _proposalId,
        address _wallet,
        uint256 _receiptId
    )
        public
        requireCognate
        requireValidProposal(_proposalId)
        requireVoteCast(_proposalId, _receiptId)
        requireReceiptForWallet(_proposalId, _receiptId, _wallet)
        requireUndo(_proposalId)
        requireVotingActive(_proposalId)
        returns (uint256)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt storage receipt = proposal.voteReceipt[_receiptId];
        require(receipt.shareFor > 0, "Vote not affirmative");
        uint256 undoVotes = receipt.shareFor;
        receipt.undoCast = true;
        proposal.forVotes -= undoVotes;
        emit UndoVote(_proposalId, _wallet, _receiptId, undoVotes);
        return undoVotes;
    }
}
