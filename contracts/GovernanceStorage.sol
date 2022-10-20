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

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../contracts/Constant.sol";
import "../contracts/Storage.sol";
import "../contracts/VoterClass.sol";

/// @title GovernanceStorage implementation
/// @notice GovernanceStorage implements the necesscary infrastructure for
/// governance and voting with safety controls
/// @dev The creator of the contract, typically the Governance contract itself,
/// privledged with respect to write opperations in this contract.   The creator
/// is required for nearly all change operations
contract GovernanceStorage is Storage, ERC165, Ownable {
    /// @notice contract name
    string public constant NAME = "collective governance storage";

    uint256 public constant MAXIMUM_QUORUM = Constant.UINT_MAX;
    uint256 public constant MAXIMUM_TIME = Constant.UINT_MAX;

    /// @notice minimum vote delay for any vote
    uint256 private immutable _minimumVoteDelay;

    /// @notice minimum time for any vote
    uint256 private immutable _minimumVoteDuration;

    /// @notice minimum quorum for any vote
    uint256 private immutable _minimumProjectQuorum;

    /// @notice Voter class for storage
    VoterClass private immutable _voterClass;

    /// @notice The total number of proposals
    uint256 private _proposalCount;

    /// @notice global list of proposed issues by id
    mapping(uint256 => Proposal) public proposalMap;

    /// @notice The last contest for each sender
    mapping(address => uint256) private _latestProposalId;

    /// @notice create a new storage object with VoterClass as the voting population
    /// @param _class the contract that defines the popluation
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    constructor(
        VoterClass _class,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _minimumDuration
    ) {
        require(_minimumDelay >= Constant.MINIMUM_VOTE_DELAY, "Delay not allowed");
        require(_minimumDuration >= Constant.MINIMUM_VOTE_DURATION, "Duration not allowed");
        require(_minimumQuorum >= Constant.MINIMUM_PROJECT_QUORUM, "Quorum invalid");
        require(_class.isFinal(), "Voter Class modifiable");
        _minimumVoteDelay = _minimumDelay;
        _minimumVoteDuration = _minimumDuration;
        _minimumProjectQuorum = _minimumQuorum;
        _voterClass = _class;
        _proposalCount = 0;
    }

    modifier requireValid(uint256 _proposalId) {
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

    modifier requireConfig(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.status == Status.CONFIG, "Vote not modifiable");
        _;
    }

    modifier requireFinal(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.status == Status.FINAL, "Not final");
        _;
    }

    modifier requireVotingActive(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.startTime <= getBlockTimestamp() && proposal.endTime > getBlockTimestamp(), "Vote not active");
        _;
    }

    modifier requireUndo(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(proposal.isUndoEnabled, "Undo not enabled");
        _;
    }

    modifier requireEditSupervisor(uint256 _proposalId, address _sender) {
        Proposal storage proposal = proposalMap[_proposalId];
        Supervisor storage supervisor = proposal.supervisorPool[_sender];
        require(supervisor.isEnabled && !supervisor.isProject, "Supervisor change not permitted");
        _;
    }

    modifier requireSupervisor(uint256 _proposalId, address _sender) {
        Proposal storage proposal = proposalMap[_proposalId];
        Supervisor storage supervisor = proposal.supervisorPool[_sender];
        require(supervisor.isEnabled, "Requires supervisor");
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
    ) external {
        registerSupervisor(_proposalId, _supervisor, false, _sender);
    }

    /// @notice Register a new supervisor on the specified proposal.
    /// The supervisor has rights to add or remove voters prior to start of voting
    /// in a Voter Pool. The supervisor also has the right to veto the outcome of the vote.
    /// @dev requires proposal creator
    /// @param _proposalId the id of the proposal
    /// @param _supervisor the supervisor address
    /// @param _isProject true if project supervisor
    /// @param _sender original wallet for this request
    function registerSupervisor(
        uint256 _proposalId,
        address _supervisor,
        bool _isProject,
        address _sender
    ) public onlyOwner requireValid(_proposalId) requireProposalSender(_proposalId, _sender) requireConfig(_proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        Supervisor storage supervisor = proposal.supervisorPool[_supervisor];
        if (!supervisor.isEnabled) {
            proposal.supervisorPool[_supervisor] = Supervisor(true, _isProject);
            emit AddSupervisor(_proposalId, _supervisor, _isProject);
        } else {
            revert("Already enabled");
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
        onlyOwner
        requireValid(_proposalId)
        requireProposalSender(_proposalId, _sender)
        requireConfig(_proposalId)
        requireEditSupervisor(_proposalId, _supervisor)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        Supervisor storage supervisor = proposal.supervisorPool[_supervisor];
        if (supervisor.isEnabled) {
            supervisor.isEnabled = false;
            emit BurnSupervisor(_proposalId, _supervisor);
        } else {
            revert("Supervisor is not enabled.");
        }
    }

    /// @notice set the minimum number of participants for a successful outcome
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _quorum the number required for quorum
    /// @param _sender original wallet for this request
    function setQuorumRequired(
        uint256 _proposalId,
        uint256 _quorum,
        address _sender
    ) external onlyOwner requireValid(_proposalId) requireConfig(_proposalId) requireSupervisor(_proposalId, _sender) {
        require(_quorum >= minimumProjectQuorum(), "Quorum not allowed");
        Proposal storage proposal = proposalMap[_proposalId];

        proposal.quorumRequired = _quorum;
        emit SetQuorumRequired(_proposalId, _quorum);
    }

    /// @notice enable the undo feature for this vote
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _sender original wallet for this request
    function enableUndoVote(uint256 _proposalId, address _sender)
        external
        onlyOwner
        requireValid(_proposalId)
        requireConfig(_proposalId)
        requireSupervisor(_proposalId, _sender)
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
    ) external onlyOwner requireValid(_proposalId) requireConfig(_proposalId) requireSupervisor(_proposalId, _sender) {
        require(_voteDelay >= minimumVoteDelay(), "Delay not allowed");
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voteDelay = _voteDelay;
        emit SetVoteDelay(_proposalId, _voteDelay);
    }

    /// @notice set the required duration for the vote
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _voteDuration the quorum number
    /// @param _sender original wallet for this request
    function setVoteDuration(
        uint256 _proposalId,
        uint256 _voteDuration,
        address _sender
    ) external onlyOwner requireValid(_proposalId) requireConfig(_proposalId) requireSupervisor(_proposalId, _sender) {
        require(_voteDuration >= minimumVoteDuration(), "Duration not allowed");
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.voteDuration = _voteDuration;
        emit SetVoteDuration(_proposalId, _voteDuration);
    }

    /// @notice get the address of the proposal sender
    /// @param _proposalId the id of the proposal
    /// @return address the address of the sender
    function getSender(uint256 _proposalId) external view requireValid(_proposalId) returns (address) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.proposalSender;
    }

    /// @notice get the quorum required
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number required for quorum
    function quorumRequired(uint256 _proposalId) external view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.quorumRequired;
    }

    /// @notice get the vote delay
    /// @param _proposalId the id of the proposal
    /// @return uint256 the delay
    function voteDelay(uint256 _proposalId) external view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voteDelay;
    }

    /// @notice get the vote duration
    /// @param _proposalId the id of the proposal
    /// @return uint256 the duration
    function voteDuration(uint256 _proposalId) external view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.voteDuration;
    }

    /// @notice get the start time
    /// @dev timestamp in epoch seconds since January 1, 1970
    /// @param _proposalId the id of the proposal
    /// @return uint256 the start time
    function startTime(uint256 _proposalId) external view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.startTime;
    }

    /// @notice get the end time
    /// @dev timestamp in epoch seconds since January 1, 1970
    /// @param _proposalId the id of the proposal
    /// @return uint256 the end time
    function endTime(uint256 _proposalId) external view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.endTime;
    }

    /// @notice get the for vote count
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number of votes in favor
    function forVotes(uint256 _proposalId) public view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.forVotes;
    }

    /// @notice get the against vote count
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number of against votes
    function againstVotes(uint256 _proposalId) public view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.againstVotes;
    }

    /// @notice get the number of abstentions
    /// @param _proposalId the id of the proposal
    /// @return uint256 the number abstentions
    function abstentionCount(uint256 _proposalId) public view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.abstentionCount;
    }

    /// @notice get the current number counting towards quorum
    /// @param _proposalId the id of the proposal
    /// @return uint256 the amount of participation
    function quorum(uint256 _proposalId) external view returns (uint256) {
        return forVotes(_proposalId) + againstVotes(_proposalId) + abstentionCount(_proposalId);
    }

    /// @notice test if the address is a supervisor on the specified proposal
    /// @param _proposalId the id of the proposal
    /// @param _supervisor the address to check
    /// @return bool true if the address is a supervisor
    function isSupervisor(uint256 _proposalId, address _supervisor) external view requireValid(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        Supervisor storage supervisor = proposal.supervisorPool[_supervisor];
        return supervisor.isEnabled;
    }

    /// @notice test if address is a voter on the specified proposal
    /// @param _proposalId the id of the proposal
    /// @param _voter the address to check
    /// @return bool true if the address is a voter
    function isVoter(uint256 _proposalId, address _voter) external view requireValid(_proposalId) returns (bool) {
        return _voterClass.isVoter(_voter);
    }

    /// @notice test if proposal is ready or in the setup phase
    /// @param _proposalId the id of the proposal
    /// @return bool true if the proposal is marked ready
    function isFinal(uint256 _proposalId) public view requireValid(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.status == Status.FINAL || proposal.status == Status.CANCELLED;
    }

    /// @notice test if proposal is cancelled
    /// @param _proposalId the id of the proposal
    /// @return bool true if the proposal is marked cancelled
    function isCancel(uint256 _proposalId) public view requireValid(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.status == Status.CANCELLED;
    }

    /// @notice test if proposal is veto
    /// @param _proposalId the id of the proposal
    /// @return bool true if the proposal is marked veto
    function isVeto(uint256 _proposalId) external view requireValid(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_proposalId > 0 && _proposalId <= _proposalCount, "Unknown proposal");
        return proposal.isVeto;
    }

    /// @notice get the id of the last proposal for sender
    /// @return uint256 the id of the most recent proposal for sender
    function latestProposal(address _sender) external view returns (uint256) {
        uint256 latestProposalId = _latestProposalId[_sender];
        require(latestProposalId > 0, "No proposal");
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
        requireValid(_proposalId)
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
    function initializeProposal(address _sender) external onlyOwner returns (uint256) {
        uint256 latestProposalId = _latestProposalId[_sender];
        if (latestProposalId != 0) {
            Proposal storage lastProposal = proposalMap[latestProposalId];
            require(isFinal(latestProposalId) && getBlockTimestamp() >= lastProposal.endTime, "Too many proposals");
        }
        _proposalCount++;
        uint256 proposalId = _proposalCount;
        _latestProposalId[_sender] = proposalId;

        // proposal
        Proposal storage proposal = proposalMap[proposalId];
        proposal.id = proposalId;
        proposal.proposalSender = _sender;
        proposal.quorumRequired = MAXIMUM_QUORUM;
        proposal.voteDelay = Constant.MINIMUM_VOTE_DELAY;
        proposal.voteDuration = Constant.MINIMUM_VOTE_DURATION;
        proposal.startTime = MAXIMUM_TIME;
        proposal.endTime = MAXIMUM_TIME;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.abstentionCount = 0;
        proposal.transactionCount = 0;
        proposal.metaCount = 0;
        proposal.isVeto = false;
        proposal.status = Status.CONFIG;
        proposal.isUndoEnabled = false;
        proposal.url = "";
        proposal.description = "";

        emit InitializeProposal(proposalId, _sender);
        return proposalId;
    }

    /// @notice indicate the proposal is ready for voting and should be frozen
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _sender original wallet for this request
    function makeFinal(uint256 _proposalId, address _sender)
        public
        onlyOwner
        requireValid(_proposalId)
        requireConfig(_proposalId)
        requireSupervisor(_proposalId, _sender)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.startTime = getBlockTimestamp() + proposal.voteDelay;
        proposal.endTime = proposal.startTime + proposal.voteDuration;
        proposal.status = Status.FINAL;
        emit VoteReady(_proposalId, proposal.startTime, proposal.endTime);
    }

    /// @notice cancel the proposal if it is not yet started
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _sender original wallet for this request
    function cancel(uint256 _proposalId, address _sender)
        external
        onlyOwner
        requireValid(_proposalId)
        requireSupervisor(_proposalId, _sender)
    {
        if (!isFinal(_proposalId)) {
            // calculate start and end time
            makeFinal(_proposalId, _sender);
        }
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.status = Status.CANCELLED;
        emit VoteCancel(_proposalId, _sender);
    }

    /// @notice veto the specified proposal
    /// @dev supervisor is required
    /// @param _proposalId the id of the proposal
    /// @param _sender the address of the veto sender
    function veto(uint256 _proposalId, address _sender)
        external
        onlyOwner
        requireValid(_proposalId)
        requireSupervisor(_proposalId, _sender)
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
        onlyOwner
        requireShareAvailable(_proposalId, _shareId)
        requireValid(_proposalId)
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
        onlyOwner
        requireValid(_proposalId)
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
    ) public onlyOwner requireValid(_proposalId) requireVotingActive(_proposalId) returns (uint256) {
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
        onlyOwner
        requireValid(_proposalId)
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

    /// @notice add a transaction to the specified proposal
    /// @param _proposalId the id of the proposal
    /// @param _target the target address for this transaction
    /// @param _value the value to pass to the call
    /// @param _signature the tranaction signature
    /// @param _calldata the call data to pass to the call
    /// @param _scheduleTime the expected call time, within the timelock grace,
    ///        for the transaction
    /// @param _txHash the transaction hash of the stored transaction
    /// @param _sender for this proposal
    /// @return uint256 the id of the transaction that was added
    function addTransaction(
        uint256 _proposalId,
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _calldata,
        uint256 _scheduleTime,
        bytes32 _txHash,
        address _sender
    )
        external
        onlyOwner
        requireConfig(_proposalId)
        requireValid(_proposalId)
        requireProposalSender(_proposalId, _sender)
        returns (uint256)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 transactionId = proposal.transactionCount++;
        proposal.transaction[transactionId] = Transaction(_target, _value, _signature, _calldata, _scheduleTime, _txHash);
        emit AddTransaction(_proposalId, transactionId, _target, _value, _scheduleTime, _txHash);
        return transactionId;
    }

    /// @notice return the stored transaction by id
    /// @param _proposalId the proposal where the transaction is stored
    /// @param _transactionId The id of the transaction on the proposal
    /// @return _target the target address for this transaction
    /// @return _value the value to pass to the call
    /// @return _signature the tranaction signature
    /// @return _calldata the call data to pass to the call
    /// @return _scheduleTime the expected call time, within the timelock grace,
    ///        for the transaction
    /// @return _txHash the transaction hash of the stored transaction
    function getTransaction(uint256 _proposalId, uint256 _transactionId)
        external
        view
        requireValid(_proposalId)
        returns (
            address _target,
            uint256 _value,
            string memory _signature,
            bytes memory _calldata,
            uint256 _scheduleTime,
            bytes32 _txHash
        )
    {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_transactionId < proposal.transactionCount, "Invalid transaction");
        Transaction storage transaction = proposal.transaction[_transactionId];
        return (
            transaction.target,
            transaction.value,
            transaction.signature,
            transaction._calldata,
            transaction.scheduleTime,
            transaction.txHash
        );
    }

    /// @notice clear a stored transaction
    /// @param _proposalId the proposal where the transaction is stored
    /// @param _transactionId The id of the transaction on the proposal
    /// @param _sender The message sender
    function clearTransaction(
        uint256 _proposalId,
        uint256 _transactionId,
        address _sender
    ) external onlyOwner requireConfig(_proposalId) requireValid(_proposalId) requireProposalSender(_proposalId, _sender) {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_transactionId < proposal.transactionCount, "Invalid transaction");
        Transaction storage transaction = proposal.transaction[_transactionId];
        (uint256 scheduleTime, bytes32 txHash) = (transaction.scheduleTime, transaction.txHash);

        transaction.target = address(0x0);
        transaction.value = 0;
        transaction.signature = "";
        transaction._calldata = "";
        transaction.scheduleTime = 0;
        transaction.txHash = "";
        delete proposal.transaction[_transactionId];
        emit ClearTransaction(_proposalId, _transactionId, scheduleTime, txHash);
    }

    /// @notice set proposal state executed
    /// @param _proposalId the id of the proposal
    /// @param _sender for this proposal
    function setExecuted(uint256 _proposalId, address _sender)
        external
        onlyOwner
        requireValid(_proposalId)
        requireFinal(_proposalId)
        requireProposalSender(_proposalId, _sender)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        require(!proposal.isExecuted, "Executed previously");
        proposal.isExecuted = true;
        emit Executed(_proposalId);
    }

    /// @notice get the current state if executed or not
    /// @param _proposalId the id of the proposal
    /// @return bool true if already executed
    function isExecuted(uint256 _proposalId) external view requireValid(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.isExecuted;
    }

    /// @notice get the number of attached transactions
    /// @param _proposalId the id of the proposal
    /// @return uint256 current number of transactions
    function transactionCount(uint256 _proposalId) external view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.transactionCount;
    }

    /// @notice get the number of attached metadata
    /// @param _proposalId the id of the proposal
    /// @return uint256 current number of meta elements
    function metaCount(uint256 _proposalId) external view requireValid(_proposalId) returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.metaCount;
    }

    /// @notice set proposal url
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _url the url
    function setProposalUrl(
        uint256 _proposalId,
        string memory _url,
        address _sender
    ) external onlyOwner requireValid(_proposalId) requireConfig(_proposalId) requireSupervisor(_proposalId, _sender) {
        require(Constant.len(_url) < Constant.STRING_DATA_LIMIT, "Url exceeds limit");
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.url = _url;
        emit SetVoteUrl(_proposalId, proposal.url);
    }

    /// @notice get the proposal url
    /// @param _proposalId the id of the proposal
    /// @return string the url
    function url(uint256 _proposalId) external view requireValid(_proposalId) returns (string memory) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.url;
    }

    /// @notice set proposal description
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _description the description
    function setProposalDescription(
        uint256 _proposalId,
        string memory _description,
        address _sender
    ) external onlyOwner requireValid(_proposalId) requireConfig(_proposalId) requireSupervisor(_proposalId, _sender) {
        require(Constant.len(_description) < Constant.STRING_DATA_LIMIT, "Description exceeds limit");
        Proposal storage proposal = proposalMap[_proposalId];
        proposal.description = _description;
        emit SetVoteDescription(_proposalId, proposal.description);
    }

    /// @notice get the proposal description
    /// @param _proposalId the id of the proposal
    /// @return string the description
    function description(uint256 _proposalId) external view requireValid(_proposalId) returns (string memory) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.description;
    }

    /// @notice attach arbitrary metadata to proposal
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _name the name of the metadata field
    /// @param _value the value of the metadata
    /// @return uint256 the metadata id
    function addMeta(
        uint256 _proposalId,
        bytes32 _name,
        string memory _value,
        address _sender
    )
        external
        onlyOwner
        requireValid(_proposalId)
        requireConfig(_proposalId)
        requireSupervisor(_proposalId, _sender)
        returns (uint256)
    {
        require(Constant.len(_value) < Constant.STRING_DATA_LIMIT, "Value exceeds limit");
        Proposal storage proposal = proposalMap[_proposalId];
        uint256 metadataId = proposal.metaCount++;
        proposal.metadata[metadataId] = Meta(metadataId, _name, _value);
        emit AddMeta(_proposalId, metadataId, _name, _value);
        return metadataId;
    }

    /// @notice get arbitrary metadata from proposal
    /// @param _proposalId the id of the proposal
    /// @param _mId the id of the metadata
    /// @return _name the name of the metadata field
    /// @return _value the value of the metadata field
    function getMeta(uint256 _proposalId, uint256 _mId)
        external
        view
        requireValid(_proposalId)
        returns (bytes32 _name, string memory _value)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        require(_mId < proposal.metaCount, "Metadata id unknown");
        Meta storage meta = proposal.metadata[_mId];
        require(meta.id == _mId, "Metadata invalid");
        return (meta.name, meta.value);
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(Storage).interfaceId ||
            interfaceId == type(Ownable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice get the project vote delay requirement
    /// @return uint the least vote delay allowed for any vote
    function minimumVoteDelay() public view returns (uint256) {
        return _minimumVoteDelay;
    }

    /// @notice get the vote duration in seconds
    /// @return uint256 the least duration of a vote in seconds
    function minimumVoteDuration() public view returns (uint256) {
        return _minimumVoteDuration;
    }

    /// @notice get the project quorum requirement
    /// @return uint256 the least quorum allowed for any vote
    function minimumProjectQuorum() public view returns (uint256) {
        return _minimumProjectQuorum;
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    /// @notice return the version of this implementation
    /// @return uint32 version number
    function version() public pure virtual returns (uint32) {
        return Constant.VERSION_1;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }
}
