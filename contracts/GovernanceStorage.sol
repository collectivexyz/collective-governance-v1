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
    string public constant NAME = "collective storage";

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

    /// @notice global map of proposed issues by id
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
        if (_minimumDelay < Constant.MINIMUM_VOTE_DELAY) revert DelayLessThanMinimum(_minimumDelay, Constant.MINIMUM_VOTE_DELAY);
        if (_minimumDuration < Constant.MINIMUM_VOTE_DURATION)
            revert DurationLessThanMinimum(_minimumDuration, Constant.MINIMUM_VOTE_DURATION);
        if (_minimumQuorum < Constant.MINIMUM_PROJECT_QUORUM)
            revert QuorumLessThanMinimum(_minimumQuorum, Constant.MINIMUM_PROJECT_QUORUM);
        if (!_class.isFinal()) revert VoterClassNotFinal(_class.name(), _class.version());

        _minimumVoteDelay = _minimumDelay;
        _minimumVoteDuration = _minimumDuration;
        _minimumProjectQuorum = _minimumQuorum;
        _voterClass = _class;
        _proposalCount = 0;
    }

    modifier requireValid(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (_proposalId == 0 || _proposalId > _proposalCount || proposal.id != _proposalId) revert InvalidProposal(_proposalId);
        _;
    }

    modifier requireVoteCast(uint256 _proposalId, uint256 _receiptId) {
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt memory receipt = proposal.voteReceipt[_receiptId];
        if (receipt.abstention || receipt.undoCast) revert VoteRescinded(_proposalId, _receiptId);
        if (receipt.votesCast == 0) revert NeverVoted(_proposalId, _receiptId);
        _;
    }

    modifier requireReceiptForWallet(
        uint256 _proposalId,
        uint256 _receiptId,
        address _wallet
    ) {
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt memory receipt = proposal.voteReceipt[_receiptId];
        if (receipt.wallet != _wallet) revert NotVoter(_proposalId, _receiptId, _wallet);
        _;
    }

    modifier requireValidReceipt(uint256 _proposalId, uint256 _receiptId) {
        if (_receiptId == 0) revert InvalidReceipt(_proposalId, _receiptId);
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt memory receipt = proposal.voteReceipt[_receiptId];
        if (receipt.shareId != _receiptId) revert NeverVoted(_proposalId, _receiptId);
        _;
    }

    modifier requireShareAvailable(
        uint256 _proposalId,
        address _wallet,
        uint256 _shareId
    ) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (_shareId == 0) revert TokenIdIsNotValid(_proposalId, _shareId);
        Receipt memory receipt = proposal.voteReceipt[_shareId];
        if (receipt.shareId != 0 || receipt.votesCast > 0 || receipt.abstention || receipt.undoCast)
            revert TokenVoted(_proposalId, _wallet, _shareId);
        _;
    }

    modifier requireProposalSender(uint256 _proposalId, address _sender) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.proposalSender != _sender) revert SenderRequired(_proposalId, _sender);
        _;
    }

    modifier requireConfig(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.status != Status.CONFIG) revert VoteFinal(_proposalId);
        _;
    }

    modifier requireFinal(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.status != Status.FINAL) revert VoteNotFinal(_proposalId);
        _;
    }

    modifier requireVotingActive(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.startTime > getBlockTimestamp() || proposal.endTime < getBlockTimestamp())
            revert VoteNotActive(_proposalId, proposal.startTime, proposal.endTime, getBlockTimestamp());
        _;
    }

    modifier requireUndo(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (!proposal.isUndoEnabled) revert UndoNotEnabled(_proposalId);
        _;
    }

    modifier requireMutableSupervisor(uint256 _proposalId, address _supervisor) {
        Proposal storage proposal = proposalMap[_proposalId];
        Supervisor memory supervisor = proposal.supervisorPool[_supervisor];
        if (!supervisor.isEnabled) revert NotSupervisor(_proposalId, _supervisor);
        if (supervisor.isProject) revert ProjectSupervisor(_proposalId, _supervisor);
        _;
    }

    modifier requireSupervisor(uint256 _proposalId, address _sender) {
        Proposal storage proposal = proposalMap[_proposalId];
        Supervisor memory supervisor = proposal.supervisorPool[_sender];
        if (!supervisor.isEnabled) revert SupervisorRequired(_proposalId, _sender);
        _;
    }

    modifier requireChoiceVoteReady(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        for (uint256 id = 0; id < proposal.choiceCount; id++) {
            Choice memory choice = proposal.choice[id];
            if (choice.id != id || choice.name == 0x0) revert ChoiceVoteRequiresSetup(_proposalId);
        }
        _;
    }

    modifier requireUpDownVote(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.choiceCount != 0) revert ChoiceRequired(_proposalId);
        _;
    }

    modifier requireChoiceVote(uint256 _proposalId) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.choiceCount == 0) revert NotChoiceVote(_proposalId);
        _;
    }

    modifier requireValidChoice(uint256 _proposalId, uint256 _choiceId) {
        Proposal storage proposal = proposalMap[_proposalId];
        if (proposal.choiceCount == 0) {
            if (_choiceId != 0) revert NotChoiceVote(_proposalId);
        } else {
            if (_choiceId >= proposal.choiceCount) revert ChoiceIdInvalid(_proposalId, _choiceId);
        }
        _;
    }

    modifier requireValidShare(uint256 _shareId) {
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
            revert SupervisorAlreadyRegistered(_proposalId, _supervisor, _sender);
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
        requireMutableSupervisor(_proposalId, _supervisor)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        Supervisor storage supervisor = proposal.supervisorPool[_supervisor];
        if (supervisor.isEnabled) {
            supervisor.isEnabled = false;
            emit BurnSupervisor(_proposalId, _supervisor);
        } else {
            revert SupervisorRequired(_proposalId, _supervisor);
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
        if (_quorum < minimumProjectQuorum()) revert QuorumNotPermitted(_proposalId, _quorum, minimumProjectQuorum());
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
        if (_voteDelay < minimumVoteDelay()) revert DelayNotPermitted(_proposalId, _voteDelay, minimumVoteDelay());
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
        if (_voteDuration < minimumVoteDuration()) revert DurationNotPermitted(_proposalId, _voteDuration, minimumVoteDuration());
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

    /// @notice get the for vote count for a choice
    /// @param _proposalId the id of the proposal
    /// @param _choiceId the id of the choice
    /// @return uint256 the number of votes in favor
    function voteCount(uint256 _proposalId, uint256 _choiceId)
        public
        view
        requireValid(_proposalId)
        requireChoiceVote(_proposalId)
        requireValidChoice(_proposalId, _choiceId)
        returns (uint256)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        Choice storage choice = proposal.choice[_choiceId];
        return choice.voteCount;
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
        if (_proposalId == 0 || _proposalId > _proposalCount) revert InvalidProposal(_proposalId);
        return proposal.isVeto;
    }

    /// @notice get the id of the last proposal for sender
    /// @return uint256 the id of the most recent proposal for sender
    function latestProposal(address _sender) external view returns (uint256) {
        uint256 latestProposalId = _latestProposalId[_sender];
        if (latestProposalId == 0) revert NoProposal(_sender);
        return latestProposalId;
    }

    /// @notice get the vote receipt
    /// @param _proposalId the id of the proposal
    /// @param _shareId the id of the share voted
    /// @return shareId the share id for the vote
    /// @return shareFor the shares cast in favor
    /// @return votesCast the number of votes cast
    /// @return choiceId the choice voted, 0 if not a choice vote
    /// @return isAbstention true if vote was an abstention
    /// @return isUndo true if the vote was reversed
    function getVoteReceipt(uint256 _proposalId, uint256 _shareId)
        external
        view
        requireValid(_proposalId)
        requireValidReceipt(_proposalId, _shareId)
        returns (
            uint256 shareId,
            uint256 shareFor,
            uint256 votesCast,
            uint256 choiceId,
            bool isAbstention,
            bool isUndo
        )
    {
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt memory receipt = proposal.voteReceipt[_shareId];
        return (receipt.shareId, receipt.shareFor, receipt.votesCast, receipt.choiceId, receipt.abstention, receipt.undoCast);
    }

    /// @notice get the VoterClass used for this voting store
    /// @return VoterClass the voter class for this store
    function voterClass() external view returns (VoterClass) {
        return _voterClass;
    }

    /// @notice initialize a new proposal and return the id
    /// @param _choiceCount The number of choices for this proposal
    /// @param _sender the proposal sender
    /// @return uint256 the id of the proposal
    function initializeProposal(uint256 _choiceCount, address _sender) external onlyOwner returns (uint256) {
        uint256 latestProposalId = _latestProposalId[_sender];
        if (latestProposalId != 0) {
            Proposal storage lastProposal = proposalMap[latestProposalId];
            if (!isFinal(latestProposalId) || getBlockTimestamp() < lastProposal.endTime)
                revert TooManyProposals(_sender, latestProposalId);
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
        proposal.choiceCount = _choiceCount;
        proposal.isVeto = false;
        proposal.status = Status.CONFIG;
        proposal.isUndoEnabled = false;

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
        requireChoiceVoteReady(_proposalId)
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
            emit VoteVeto(_proposalId, _sender);
        } else {
            revert AlreadyVetoed(_proposalId, _sender);
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
    ) external requireUpDownVote(_proposalId) returns (uint256) {
        return voteForByShare(_proposalId, _wallet, _shareId, 0);
    }

    /// @notice cast an affirmative vote for the specified share
    /// @param _proposalId the id of the proposal
    /// @param _wallet the wallet represented for the vote
    /// @param _shareId the id of the share
    /// @param _choiceId The choice to vote for
    /// @return uint256 the number of votes cast
    function voteForByShare(
        uint256 _proposalId,
        address _wallet,
        uint256 _shareId,
        uint256 _choiceId
    )
        public
        onlyOwner
        requireShareAvailable(_proposalId, _wallet, _shareId)
        requireValid(_proposalId)
        requireVotingActive(_proposalId)
        requireValidChoice(_proposalId, _choiceId)
        returns (uint256)
    {
        uint256 _shareCount = _voterClass.confirm(_wallet, _shareId);
        if (_shareCount == 0) revert InvalidTokenId(_proposalId, _wallet, _shareId);
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt storage receipt = proposal.voteReceipt[_shareId];
        receipt.wallet = _wallet;
        receipt.shareId = _shareId;
        receipt.shareFor = _shareCount;
        receipt.votesCast = _shareCount;
        receipt.choiceId = _choiceId;
        receipt.abstention = false;
        receipt.undoCast = false;
        proposal.forVotes += _shareCount;
        if (isChoiceVote(_proposalId)) {
            Choice storage choice = proposal.choice[_choiceId];
            choice.voteCount += _shareCount;
            emit VoteCast(_proposalId, _wallet, _shareId, _choiceId, _shareCount);
        } else {
            emit VoteCast(_proposalId, _wallet, _shareId, _shareCount);
        }

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
        requireShareAvailable(_proposalId, _wallet, _shareId)
        requireVotingActive(_proposalId)
        requireUpDownVote(_proposalId)
        returns (uint256)
    {
        uint256 _shareCount = _voterClass.confirm(_wallet, _shareId);
        if (_shareCount == 0) revert InvalidTokenId(_proposalId, _wallet, _shareId);
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt storage receipt = proposal.voteReceipt[_shareId];
        receipt.wallet = _wallet;
        receipt.shareId = _shareId;
        receipt.shareFor = 0;
        receipt.votesCast = _shareCount;
        receipt.abstention = false;
        receipt.undoCast = false;
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
    )
        public
        onlyOwner
        requireValid(_proposalId)
        requireShareAvailable(_proposalId, _wallet, _shareId)
        requireVotingActive(_proposalId)
        returns (uint256)
    {
        uint256 _shareCount = _voterClass.confirm(_wallet, _shareId);
        if (_shareCount == 0) revert InvalidTokenId(_proposalId, _wallet, _shareId);
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt storage receipt = proposal.voteReceipt[_shareId];
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
        requireValidReceipt(_proposalId, _receiptId)
        requireVoteCast(_proposalId, _receiptId)
        requireReceiptForWallet(_proposalId, _receiptId, _wallet)
        requireUndo(_proposalId)
        requireVotingActive(_proposalId)
        returns (uint256)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        Receipt storage receipt = proposal.voteReceipt[_receiptId];
        if (receipt.shareFor == 0) revert AffirmativeVoteRequired(_proposalId, _receiptId);
        uint256 undoVotes = receipt.shareFor;
        receipt.undoCast = true;
        proposal.forVotes -= undoVotes;
        if (proposal.choiceCount > 0) {
            Choice memory choice = proposal.choice[receipt.choiceId];
            choice.voteCount -= undoVotes;
        }
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
        if (_transactionId >= proposal.transactionCount) revert InvalidTransaction(_proposalId, _transactionId);
        Transaction memory transaction = proposal.transaction[_transactionId];
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
        if (_transactionId >= proposal.transactionCount) revert InvalidTransaction(_proposalId, _transactionId);
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
        if (proposal.isExecuted) revert MarkedExecuted(_proposalId);
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

    /// @notice get the number of attached choices
    /// @param _proposalId the id of the proposal
    /// @return uint current number of choices
    function choiceCount(uint256 _proposalId) external view returns (uint256) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.choiceCount;
    }

    /// @notice set a choice by choice id
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _name the name of the metadata field
    /// @param _description the detailed description of the choice
    /// @param _transactionId The id of the transaction to execute
    /// @param _sender The sender of the choice
    function setChoice(
        uint256 _proposalId,
        uint256 _choiceId,
        bytes32 _name,
        string memory _description,
        uint256 _transactionId,
        address _sender
    )
        external
        onlyOwner
        requireValid(_proposalId)
        requireConfig(_proposalId)
        requireSupervisor(_proposalId, _sender)
        requireChoiceVote(_proposalId)
    {
        if (_name == 0x0) revert ChoiceNameRequired(_proposalId, _choiceId);
        uint256 descLen = Constant.len(_description);
        if (descLen > Constant.STRING_DATA_LIMIT)
            revert ChoiceDescriptionExceedsDataLimit(_proposalId, _choiceId, descLen, Constant.STRING_DATA_LIMIT);
        Proposal storage proposal = proposalMap[_proposalId];
        if (_choiceId >= proposal.choiceCount) revert ChoiceIdInvalid(_proposalId, _choiceId);
        if (_transactionId != 0 && _transactionId >= proposal.transactionCount)
            revert ChoiceTransactionIdInvalid(_proposalId, _choiceId, _transactionId);
        proposal.choice[_choiceId] = Choice(_choiceId, _name, _description, _transactionId, 0);
        emit SetChoice(_proposalId, _choiceId, _name, _description, _transactionId);
    }

    /// @notice get the choice by id
    /// @param _proposalId the id of the proposal
    /// @param _choiceId the id of the choice
    /// @return _name the name of the choice field
    /// @return _description the string choice description
    /// @return _transactionId the transactionId to execute for this choice
    /// @return _voteCount the current number of votes for this choice
    function getChoice(uint256 _proposalId, uint256 _choiceId)
        external
        view
        requireValid(_proposalId)
        requireChoiceVote(_proposalId)
        returns (
            bytes32 _name,
            string memory _description,
            uint256 _transactionId,
            uint256 _voteCount
        )
    {
        Proposal storage proposal = proposalMap[_proposalId];
        if (_choiceId >= proposal.choiceCount) revert ChoiceIdInvalid(_proposalId, _choiceId);
        Choice memory choice = proposal.choice[_choiceId];
        if (_choiceId != choice.id) revert ChoiceNotInitialized(_proposalId, _choiceId);
        return (choice.name, choice.description, choice.transactionId, choice.voteCount);
    }

    /// @notice get the choice description by id
    /// @param _proposalId the id of the proposal
    /// @param _choiceId the id of the metadata
    /// @return string the description
    function getChoiceDescription(uint256 _proposalId, uint256 _choiceId)
        external
        view
        requireValid(_proposalId)
        requireValidChoice(_proposalId, _choiceId)
        returns (string memory)
    {
        Proposal storage proposal = proposalMap[_proposalId];
        Choice memory choice = proposal.choice[_choiceId];
        if (_choiceId != choice.id) revert ChoiceNotInitialized(_proposalId, _choiceId);
        return choice.description;
    }

    /// @notice return the choice with the highest vote count
    /// @dev quorum is ignored for this caluclation
    /// @param _proposalId the id of the proposal
    /// @return uint The winning choice
    function getWinningChoice(uint256 _proposalId) external view requireChoiceVote(_proposalId) returns (uint256) {
        uint256 winningChoice = 0;
        uint256 highestVoteCount = 0;
        Proposal storage proposal = proposalMap[_proposalId];
        for (uint256 cid = 0; cid < proposal.choiceCount; cid++) {
            Choice memory choice = proposal.choice[cid];
            if (choice.voteCount > highestVoteCount) {
                winningChoice = cid;
                highestVoteCount = choice.voteCount;
            }
        }
        return winningChoice;
    }

    /// @notice test if proposal is a choice vote
    /// @param _proposalId the id of the proposal
    /// @return bool true if proposal is a choice vote
    function isChoiceVote(uint256 _proposalId) public view requireValid(_proposalId) returns (bool) {
        Proposal storage proposal = proposalMap[_proposalId];
        return proposal.choiceCount > 0;
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
