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

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "../contracts/Storage.sol";
import "../contracts/VoterClass.sol";

/// @title GovernanceStorage implementation
/// @notice GovernanceStorage implements the necesscary infrastructure for
/// governance and voting with safety controls
/// @dev The creator of the contract, typically the Governance contract itself,
/// privledged with respect to write opperations in this contract.   The creator
/// is required for nearly all change operations
contract GovernanceStorage is Storage, ERC165 {
    /// @notice contract name
    string public constant NAME = "collective.xyz governance storage";
    uint32 public constant VERSION_1 = 1;

    uint256 public constant UINT_MAX = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 public constant MAXIMUM_QUORUM = UINT_MAX;
    uint256 public constant MAXIMUM_BLOCK = UINT_MAX;
    uint256 public constant MINIMUM_VOTE_DURATION = 1;

    /// @notice only the peer contract may modify the vote
    address private immutable _cognate;

    /// @notice Voter class for storage
    VoterClass private immutable _voterClass;

    /// @notice The total number of proposals
    uint256 private _proposalCount;

    /// @notice global list of proposed issues by id
    mapping(uint256 => Proposal) public proposalMap;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) private _latestProposalId;

    /// @notice create a new storage object with VoterClass as the voting population
    /// @param _class the contract that defines the popluation
    constructor(VoterClass _class) {
        _cognate = msg.sender;
        _voterClass = _class;
        _proposalCount = 0;
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
        require(receipt.shareId == 0 && receipt.votesCast == 0 && !receipt.abstention && !receipt.undoCast, "Already voted");
        _;
    }

    modifier requireProposalSender(uint256 _proposalId, address _sender) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.proposalSender == _sender, "Not creator");
        _;
    }

    modifier requireElectorSupervisor(uint256 _proposalId, address _sender) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.supervisorPool[_sender], "Requires supervisor");
        _;
    }

    modifier requireVotingNotReady(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(!proposal.isReady, "Vote not modifiable");
        _;
    }

    modifier requireVotingReady(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.isReady, "Not ready");
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
    )
        external
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

    /// @notice remove a supervisor from the proposal along with its ability to change or veto
    /// @dev requires proposal creator
    /// @param _proposalId the id of the proposal
    /// @param _supervisor the supervisor address
    /// @param _sender original wallet for this request
    function burnSupervisor(
        uint256 _proposalId,
        address _supervisor,
        address _sender
    )
        external
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

    /// @notice set the minimum number of participants for a successful outcome
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _threshold the quorum number
    /// @param _sender original wallet for this request
    function setQuorumThreshold(
        uint256 _proposalId,
        uint256 _threshold,
        address _sender
    )
        external
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.quorumRequired = _threshold;
        emit SetQuorumThreshold(_proposalId, _threshold);
    }

    /// @notice enable the undo feature for this vote
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _sender original wallet for this request
    function enableUndoVote(uint256 _proposalId, address _sender)
        external
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.isUndoEnabled = true;
        emit UndoVoteEnabled(_proposalId);
    }

    /// @notice set the delay period required to preceed the vote
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _voteDelay the quorum number
    /// @param _sender original wallet for this request
    function setVoteDelay(
        uint256 _proposalId,
        uint256 _voteDelay,
        address _sender
    )
        external
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voteDelay = _voteDelay;
    }

    /// @notice set the required duration for the vote
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _voteDuration the quorum number
    /// @param _sender original wallet for this request
    function setRequiredVoteDuration(
        uint256 _proposalId,
        uint256 _voteDuration,
        address _sender
    )
        external
        requireCognate
        requireValidProposal(_proposalId)
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingNotReady(_proposalId)
    {
        require(_voteDuration >= MINIMUM_VOTE_DURATION, "Voting duration is not valid");
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voteDuration = _voteDuration;
    }

    /// @notice get the address of the proposal sender
    /// @param _proposalId the id of the proposal
    /// @return address the address of the sender
    function getSender(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (address) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.proposalSender;
    }

    /// @notice get the quorum required
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number required for quorum
    function quorumRequired(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.quorumRequired;
    }

    /// @notice get the vote delay
    /// @param _proposalId the id of the proposal
    /// @return uint256 the delay
    function voteDelay(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voteDelay;
    }

    /// @notice get the vote duration
    /// @param _proposalId the id of the proposal
    /// @return uint256 the duration
    function voteDuration(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voteDuration;
    }

    /// @notice get the start block
    /// @param _proposalId the id of the proposal
    /// @return uint256 the start block
    function startBlock(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.startBlock;
    }

    /// @notice get the end block
    /// @param _proposalId the id of the proposal
    /// @return uint256 the end block
    function endBlock(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.endBlock;
    }

    /// @notice get the for vote count
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number of votes in favor
    function forVotes(uint256 _proposalId) public view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.forVotes;
    }

    /// @notice get the against vote count
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number of against votes
    function againstVotes(uint256 _proposalId) public view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.againstVotes;
    }

    /// @notice get the number of abstentions
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number abstentions
    function abstentionCount(uint256 _proposalId) public view requireValidProposal(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.abstentionCount;
    }

    /// @notice get the current number counting towards quorum
    /// @param _proposalId the id of the proposal
    /// @return uint256 the amount of participation
    function quorum(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (uint256) {
        return forVotes(_proposalId) + againstVotes(_proposalId) + abstentionCount(_proposalId);
    }

    /// @notice test if the address is a supervisor on the specified proposal
    /// @param _proposalId the id of the proposal
    /// @param _supervisor the address to check
    /// @return bool true if the address is a supervisor
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

    /// @notice test if address is a voter on the specified proposal
    /// @param _proposalId the id of the proposal
    /// @param _voter the address to check
    /// @return bool true if the address is a voter
    function isVoter(uint256 _proposalId, address _voter)
        external
        view
        requireValidAddress(_voter)
        requireValidProposal(_proposalId)
        returns (bool)
    {
        return _voterClass.isVoter(_voter);
    }

    /// @notice test if proposal is ready or in the setup phase
    /// @param _proposalId the id of the proposal
    /// @return bool true if the proposal is marked ready
    function isReady(uint256 _proposalId) external view requireValidProposal(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.isReady;
    }

    /// @notice test if proposal is cancelled
    /// @param _proposalId the id of the proposal
    /// @return bool true if the proposal is marked cancelled
    function isCancel(uint256 _proposalId) external view returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.isCancel;
    }

    /// @notice test if proposal is veto
    /// @param _proposalId the id of the proposal
    /// @return bool true if the proposal is marked veto
    function isVeto(uint256 _proposalId) external view returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_proposalId > 0 && _proposalId <= _proposalCount, "Unknown proposal");
        return proposal.isVeto;
    }

    /// @notice get the id of the last proposal for sender
    /// @return uint256 the id of the most recent proposal for sender
    function latestProposal(address _sender) external view returns (uint256) {
        uint256 latestProposalId = _latestProposalId[_sender];
        require(latestProposalId > 0, "No current proposal");
        return latestProposalId;
    }

    /// @notice get the vote receipt
    /// @return _shareId the share id for the vote
    /// @return _shareFor the shares cast in favor
    /// @return _votesCast the number of votes cast
    /// @return _isAbstention true if vote was an abstention
    /// @return _isUndo true if the vote was reversed
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

    /// @notice get the VoterClass used for this voting store
    /// @return VoterClass the voter class for this store
    function voterClass() external view returns (VoterClass) {
        return _voterClass;
    }

    /// @notice initialize a new proposal and return the id
    /// @return uint256 the id of the proposal
    function initializeProposal(address _sender) external requireCognate returns (uint256) {
        uint256 latestProposalId = _latestProposalId[_sender];
        if (latestProposalId != 0) {
            Proposal storage lastProposal = proposalMap[latestProposalId];
            require(lastProposal.isReady && block.number >= lastProposal.endBlock, "Too many proposals");
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
        proposal.startBlock = MAXIMUM_BLOCK;
        proposal.endBlock = MAXIMUM_BLOCK;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.abstentionCount = 0;
        proposal.isVeto = false;
        proposal.isReady = false;
        proposal.isUndoEnabled = false;

        emit InitializeProposal(proposalId, _sender);
        return proposalId;
    }

    /// @notice indicate the proposal is ready for voting and should be frozen
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _sender original wallet for this request
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

    /// @notice cancel the proposal if it is not yet started
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _sender original wallet for this request
    function cancel(uint256 _proposalId, address _sender)
        external
        requireCognate
        requireElectorSupervisor(_proposalId, _sender)
        requireVotingReady(_proposalId)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.isCancel = true;
        emit VoteCancel(_proposalId, _sender);
    }

    /// @notice veto the specified proposal
    /// @dev supervisor is required
    /// @param _proposalId the id of the proposal
    /// @param _sender the address of the veto sender
    function veto(uint256 _proposalId, address _sender)
        external
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

    /// @notice cast an affirmative vote for the specified share
    /// @param _proposalId the id of the proposal
    /// @param _wallet the wallet represented for the vote
    /// @param _shareId the id of the share
    /// @return uint256 the number of votes cast
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
        uint256 _shareCount = _voterClass.confirm(_wallet, _shareId);
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

    /// @notice cast an against vote for the specified share
    /// @param _proposalId the id of the proposal
    /// @param _wallet the wallet represented for the vote
    /// @param _shareId the id of the share
    /// @return uint256 the number of votes cast
    function voteAgainstByShare(
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
        uint256 _shareCount = _voterClass.confirm(_wallet, _shareId);
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

    /// @notice cast an abstention for the specified share
    /// @param _proposalId the id of the proposal
    /// @param _wallet the wallet represented for the vote
    /// @param _shareId the id of the share
    /// @return uint256 the number of votes cast
    function abstainForShare(
        uint256 _proposalId,
        address _wallet,
        uint256 _shareId
    ) public requireCognate requireValidProposal(_proposalId) requireVotingActive(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 _shareCount = _voterClass.confirm(_wallet, _shareId);
        require(_shareCount > 0, "Share not available");
        Receipt storage receipt = proposal.voteReceipt[_shareId];
        require(receipt.shareId == 0 && receipt.votesCast == 0, "Share already voted");
        receipt.wallet = _wallet;
        receipt.shareId = _shareId;
        receipt.votesCast = _shareCount;
        receipt.abstention = true;
        proposal.abstentionCount += _shareCount;
        emit VoteCast(_proposalId, _wallet, _shareId, _shareCount);
        return _shareCount;
    }

    /// @notice undo vote for the specified receipt
    /// @param _proposalId the id of the proposal
    /// @param _wallet the wallet represented for the vote
    /// @param _receiptId the id of the share to undo
    /// @return uint256 the number of votes cast
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

    /// @notice do nothing or revert if the proposal is not valid
    /// @param _proposalId the id of the proposal
    function validOrRevert(uint256 _proposalId)
        external
        view
        requireCognate
        requireValidProposal(_proposalId)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(Storage).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice get the maxiumum possible for the pass threshold
    /// @return uint256 the maximum value
    function maxPassThreshold() external pure returns (uint256) {
        return MAXIMUM_QUORUM;
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    /// @notice return the version of this implementation
    /// @return uint32 version number
    function version() public pure virtual returns (uint32) {
        return VERSION_1;
    }
}
