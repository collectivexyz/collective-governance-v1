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
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../contracts/Storage.sol";
import "../contracts/Governance.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/VoterClass.sol";
import "../contracts/VoterClassERC721.sol";
import "../contracts/VoterClassOpenVote.sol";
import "../contracts/TimeLock.sol";

/// @title Collective Governance implementation
/// @notice Governance contract implementation for Collective.   This contract implements voting by
/// groups of pooled voters, open voting or based on membership, such as class members who hold a specific
/// ERC-721 token in their wallet.
/// Creating a Vote is a three step process
///
/// First, propose the vote.  Next, Configure the vote.  Finally, start the vote.
///
/// Voting may proceed according to the conditions established during configuration.
///
/// @dev The VoterClass is common to all proposed votes as are the project supervisors.   Individual supervisors may
/// be configured as part of the proposal creation workflow but project supervisors are always included.
contract CollectiveGovernance is Governance, VoteStrategy, ERC165 {
    /// @notice contract name
    string public constant NAME = "collective governance";
    uint32 public constant VERSION_1 = 1;

    VoterClass private immutable _voterClass;

    Storage private immutable _storage;

    TimeLocker private immutable _timeLock;

    address[] private _communitySupervisorList;

    uint256 public immutable _maximumGasUsedRebate;

    uint256 public immutable _maximumBaseFeeRebate;

    /// @notice voting is open or not
    mapping(uint256 => bool) private isVoteOpenByProposalId;

    /// @notice create a new collective governance contract
    /// @dev This should be invoked through the GovernanceBuilder.  Gas Rebate
    /// is contingent on contract being funded through a transfer.
    /// @param _supervisorList the list of supervisors for this project
    /// @param _class the VoterClass for this project
    /// @param _governanceStorage The storage contract for this governance
    /// @param _gasUsedRebate The maximum rebate for gas used
    /// @param _baseFeeRebate The maximum base fee rebate
    ///
    constructor(
        address[] memory _supervisorList,
        VoterClass _class,
        Storage _governanceStorage,
        TimeLocker _timeLocker,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate
    ) {
        require(_supervisorList.length > 0, "Supervisor required");
        require(_gasUsedRebate >= Constant.MAXIMUM_REBATE_GAS_USED, "Insufficient gas used rebate");
        require(_baseFeeRebate >= Constant.MAXIMUM_REBATE_BASE_FEE, "Insufficient base fee rebate");

        _voterClass = _class;
        _storage = _governanceStorage;
        _timeLock = _timeLocker;
        _communitySupervisorList = _supervisorList;
        _maximumGasUsedRebate = _gasUsedRebate;
        _maximumBaseFeeRebate = _baseFeeRebate;
    }

    modifier requireVoteReady(uint256 _proposalId) {
        require(_storage.isFinal(_proposalId), "Voting is not ready");
        _;
    }

    modifier requireVoteClosed(uint256 _proposalId) {
        require(_storage.isFinal(_proposalId) && !isVoteOpenByProposalId[_proposalId], "Vote is not closed");
        _;
    }

    modifier requireVoteOpen(uint256 _proposalId) {
        require(_storage.isFinal(_proposalId) && isVoteOpenByProposalId[_proposalId], "Voting is closed");
        _;
    }

    modifier requireVoteAllowed(uint256 _proposalId) {
        require(!_storage.isCancel(_proposalId) && !_storage.isVeto(_proposalId), "Vote cancelled");
        _;
    }

    modifier requireSupervisor(uint256 _proposalId) {
        require(_storage.isSupervisor(_proposalId, msg.sender), "Supervisor required");
        _;
    }

    // vote only allowed from a wallet not from contract
    modifier requireOrigin() {
        // solhint-disable-next-line avoid-tx-origin
        require(tx.origin == msg.sender, "Not origin");
        _;
    }

    receive() external payable {
        emit RebateFund(msg.sender, msg.value, getRebateBalance());
    }

    // solhint-disable-next-line payable-fallback
    fallback() external {
        revert NotPermitted(msg.sender);
    }

    /// @notice propose a vote for the community
    /// @dev Only one new proposal is allowed per msg.sender
    /// @return uint256 The id of the new proposal
    function propose() external returns (uint256) {
        address _sender = msg.sender;
        uint256 proposalId = _storage.initializeProposal(_sender);
        for (uint256 i = 0; i < _communitySupervisorList.length; i++) {
            _storage.registerSupervisor(proposalId, _communitySupervisorList[i], true, _sender);
        }
        if (!_storage.isSupervisor(proposalId, _sender)) {
            _storage.registerSupervisor(proposalId, _sender, _sender);
        }
        emit ProposalCreated(_sender, proposalId);
        return proposalId;
    }

    /// @notice Attach a transaction to the specified proposal.
    ///         If successfull, it will be executed when voting is ended.
    /// @dev required prior to calling configure
    /// @param _proposalId the id of the proposal
    /// @param _target the target address for this transaction
    /// @param _value the value to pass to the call
    /// @param _signature the tranaction signature
    /// @param _calldata the call data to pass to the call
    /// @param _scheduleTime the expected call time, within the timelock grace,
    ///        for the transaction
    /// @return uint256 the transactionId
    function attachTransaction(
        uint256 _proposalId,
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _calldata,
        uint256 _scheduleTime
    ) external returns (uint256) {
        require(_storage.getSender(_proposalId) == msg.sender, "Not sender");
        bytes32 txHash = _timeLock.queueTransaction(_target, _value, _signature, _calldata, _scheduleTime);
        uint256 transactionId = _storage.addTransaction(
            _proposalId,
            _target,
            _value,
            _signature,
            _calldata,
            _scheduleTime,
            txHash,
            msg.sender
        );
        emit ProposalTransactionAttached(msg.sender, _proposalId, transactionId, _target, _value, _scheduleTime, txHash);
        return transactionId;
    }

    /// @notice describe a proposal
    /// @param _proposalId the numeric id of the proposed vote
    /// @param _description the description
    /// @param _url for proposed vote
    /// @dev required prior to calling configure
    function describe(
        uint256 _proposalId,
        string memory _description,
        string memory _url
    ) external {
        require(_storage.getSender(_proposalId) == msg.sender, "Not sender");
        _storage.setProposalDescription(_proposalId, _description, msg.sender);
        _storage.setProposalUrl(_proposalId, _url, msg.sender);
        emit ProposalDescription(_proposalId, _description, _url);
    }

    /// @notice attach arbitrary metadata to proposal
    /// @dev required prior to calling configure
    /// @param _proposalId the id of the proposal
    /// @param _name the name of the metadata field
    /// @param _value the value of the metadata
    /// @return uint256 the metadata id
    function addMeta(
        uint256 _proposalId,
        bytes32 _name,
        string memory _value
    ) external returns (uint256) {
        uint256 metaId = _storage.addMeta(_proposalId, _name, _value, msg.sender);
        emit ProposalMeta(_proposalId, metaId, _name, _value, msg.sender);
        return metaId;
    }

    /// @notice configure an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _quorumRequired The threshold of participation that is required for a successful conclusion of voting
    function configure(uint256 _proposalId, uint256 _quorumRequired) public requireSupervisor(_proposalId) {
        address _sender = msg.sender;
        _storage.setQuorumRequired(_proposalId, _quorumRequired, _sender);
        _storage.makeFinal(_proposalId, _sender);
        emit ProposalOpen(_proposalId);
    }

    /// @notice configure an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _quorumRequired The threshold of participation that is required for a successful conclusion of voting
    /// @param _requiredDelay The minimum time required before the start of voting
    /// @param _requiredDuration The minimum time for voting to proceed before ending the vote is allowed
    function configure(
        uint256 _proposalId,
        uint256 _quorumRequired,
        uint256 _requiredDelay,
        uint256 _requiredDuration
    ) external requireSupervisor(_proposalId) {
        address _sender = msg.sender;
        _storage.setVoteDelay(_proposalId, _requiredDelay, _sender);
        _storage.setVoteDuration(_proposalId, _requiredDuration, _sender);
        configure(_proposalId, _quorumRequired);
    }

    /// @notice start the voting process by proposal id
    /// @param _proposalId The numeric id of the proposed vote
    function startVote(uint256 _proposalId)
        external
        requireSupervisor(_proposalId)
        requireVoteReady(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        require(_storage.quorumRequired(_proposalId) < Constant.UINT_MAX, "Quorum required");
        if (!isVoteOpenByProposalId[_proposalId]) {
            isVoteOpenByProposalId[_proposalId] = true;
            emit VoteOpen(_proposalId);
        } else {
            revert("Already open");
        }
    }

    /// @notice test if an existing proposal is open
    /// @param _proposalId The numeric id of the proposed vote
    /// @return bool True if the proposal is open
    function isOpen(uint256 _proposalId) external view returns (bool) {
        uint256 endTime = _storage.endTime(_proposalId);
        bool voteProceeding = !_storage.isCancel(_proposalId) && !_storage.isVeto(_proposalId);
        return isVoteOpenByProposalId[_proposalId] && getBlockTimestamp() < endTime && voteProceeding;
    }

    /// @notice End voting on an existing proposal by id.  All scheduled transactions are cancelled and nothing is executed.
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev It is not possible to end voting until the required duration has elapsed.
    function endVoteAndCancelTransaction(uint256 _proposalId)
        external
        requireSupervisor(_proposalId)
        requireVoteOpen(_proposalId)
    {
        uint256 _endTime = _storage.endTime(_proposalId);
        require(
            _endTime <= getBlockTimestamp() || _storage.isVeto(_proposalId) || _storage.isCancel(_proposalId),
            "Vote in progress"
        );
        isVoteOpenByProposalId[_proposalId] = false;

        cancelTransaction(_proposalId);

        emit VoteClosed(_proposalId);
        emit ProposalClosed(_proposalId);
    }

    /// @notice end voting on an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev it is not possible to end voting until the required duration has elapsed
    function endVote(uint256 _proposalId) public requireSupervisor(_proposalId) requireVoteOpen(_proposalId) {
        uint256 _endTime = _storage.endTime(_proposalId);
        require(
            _endTime <= getBlockTimestamp() || _storage.isVeto(_proposalId) || _storage.isCancel(_proposalId),
            "Vote in progress"
        );
        isVoteOpenByProposalId[_proposalId] = false;

        if (!_storage.isVeto(_proposalId) && getVoteSucceeded(_proposalId)) {
            executeTransaction(_proposalId);
        } else {
            cancelTransaction(_proposalId);
        }
        emit VoteClosed(_proposalId);
        emit ProposalClosed(_proposalId);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev Auto discovery is attempted and if possible the method will proceed using the discovered shares
    function voteFor(uint256 _proposalId) external requireOrigin requireVoteOpen(_proposalId) requireVoteAllowed(_proposalId) {
        uint256 startGas = gasleft();
        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        for (uint256 i = 0; i < _shareList.length; i++) {
            castVoteFor(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _shareList A array of tokens or shares that confer the right to vote
    function voteFor(uint256 _proposalId, uint256[] memory _shareList)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        for (uint256 i = 0; i < _shareList.length; i++) {
            castVoteFor(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function voteFor(uint256 _proposalId, uint256 _tokenId)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        castVoteFor(_proposalId, _tokenId);
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an against vote by id
    /// @dev auto discovery is attempted and if possible the method will proceed using the discovered shares
    /// @param _proposalId The numeric id of the proposed vote
    function voteAgainst(uint256 _proposalId)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        for (uint256 i = 0; i < _shareList.length; i++) {
            castVoteAgainst(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an against vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _shareList A array of tokens or shares that confer the right to vote
    function voteAgainst(uint256 _proposalId, uint256[] memory _shareList)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        for (uint256 i = 0; i < _shareList.length; i++) {
            castVoteAgainst(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an against vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function voteAgainst(uint256 _proposalId, uint256 _tokenId)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        castVoteAgainst(_proposalId, _tokenId);
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice abstain from vote by id
    /// @dev auto discovery is attempted and if possible the method will proceed using the discovered shares
    /// @param _proposalId The numeric id of the proposed vote
    function abstainFrom(uint256 _proposalId)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        for (uint256 i = 0; i < _shareList.length; i++) {
            castAbstention(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice abstain from vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _shareList A array of tokens or shares that confer the right to vote
    function abstainFrom(uint256 _proposalId, uint256[] memory _shareList)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        for (uint256 i = 0; i < _shareList.length; i++) {
            castAbstention(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice abstain from vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function abstainFrom(uint256 _proposalId, uint256 _tokenId)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        castAbstention(_proposalId, _tokenId);
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice undo any previous vote if any
    /// @dev Only applies to affirmative vote.
    /// auto discovery is attempted and if possible the method will proceed using the discovered shares
    /// @param _proposalId The numeric id of the proposed vote
    function undoVote(uint256 _proposalId) external requireOrigin requireVoteOpen(_proposalId) requireVoteAllowed(_proposalId) {
        uint256 startGas = gasleft();
        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        for (uint256 i = 0; i < _shareList.length; i++) {
            _undoVote(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice undo any previous vote if any
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _shareList A array of tokens or shares that confer the right to vote
    function undoVote(uint256 _proposalId, uint256[] memory _shareList)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        for (uint256 i = 0; i < _shareList.length; i++) {
            _undoVote(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice undo any previous vote if any
    /// @dev only applies to affirmative vote
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function undoVote(uint256 _proposalId, uint256 _tokenId)
        external
        requireOrigin
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        uint256 startGas = gasleft();
        _undoVote(_proposalId, _tokenId);
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice veto proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev transaction must be signed by a supervisor wallet
    function veto(uint256 _proposalId)
        external
        requireSupervisor(_proposalId)
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        _storage.veto(_proposalId, msg.sender);
        emit ProposalVeto(_proposalId, msg.sender);
    }

    /// @notice get the result of the vote
    /// @return bool True if the vote is closed and passed
    /// @dev This method will fail if the vote was vetoed
    function getVoteSucceeded(uint256 _proposalId)
        public
        view
        requireVoteAllowed(_proposalId)
        requireVoteClosed(_proposalId)
        returns (bool)
    {
        uint256 totalVotesCast = _storage.quorum(_proposalId);
        bool quorumRequirementMet = totalVotesCast >= _storage.quorumRequired(_proposalId);
        return quorumRequirementMet && _storage.forVotes(_proposalId) > _storage.againstVotes(_proposalId);
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(Governance).interfaceId ||
            interfaceId == type(VoteStrategy).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice return the address of the internal vote data store
    /// @return address The address of the store
    function getStorageAddress() external view returns (address) {
        return address(_storage);
    }

    /// @notice cancel a proposal if it is not yet open
    /// @dev proposal must be finalized and ready but voting must not yet be open
    /// @param _proposalId The numeric id of the proposed vote
    function cancel(uint256 _proposalId) public requireSupervisor(_proposalId) {
        uint256 _startTime = _storage.startTime(_proposalId);
        require(!isVoteOpenByProposalId[_proposalId] && getBlockTimestamp() <= _startTime, "Not possible");
        uint256 transactionCount = _storage.transactionCount(_proposalId);
        for (uint256 tid = 0; tid < transactionCount; tid++) {
            (
                address target,
                uint256 value,
                string memory signature,
                bytes memory _calldata,
                uint256 scheduleTime,
                bytes32 txHash
            ) = _storage.getTransaction(_proposalId, tid);
            _timeLock.cancelTransaction(target, value, signature, _calldata, scheduleTime);
            _storage.clearTransaction(_proposalId, tid, msg.sender);
            emit ProposalTransactionCancelled(_proposalId, tid, target, value, scheduleTime, txHash);
        }
        _storage.cancel(_proposalId, msg.sender);
        emit ProposalClosed(_proposalId);
    }

    function executeTransaction(uint256 _proposalId) private {
        uint256 transactionCount = _storage.transactionCount(_proposalId);
        uint256 executedCount = 0;
        if (transactionCount > 0) {
            _storage.setExecuted(_proposalId, msg.sender);
            for (uint256 tid = 0; tid < transactionCount; tid++) {
                (
                    address target,
                    uint256 value,
                    string memory signature,
                    bytes memory _calldata,
                    uint256 scheduleTime,
                    bytes32 txHash
                ) = _storage.getTransaction(_proposalId, tid);
                if (txHash.length > 0 && _timeLock.queuedTransaction(txHash)) {
                    _timeLock.executeTransaction(target, value, signature, _calldata, scheduleTime);
                    emit ProposalTransactionExecuted(_proposalId, tid, target, value, scheduleTime, txHash);
                    executedCount++;
                }
            }
            emit ProposalExecuted(_proposalId, executedCount);
        }
    }

    function cancelTransaction(uint256 _proposalId) private {
        uint256 transactionCount = _storage.transactionCount(_proposalId);
        if (transactionCount > 0) {
            for (uint256 tid = 0; tid < transactionCount; tid++) {
                (
                    address target,
                    uint256 value,
                    string memory signature,
                    bytes memory _calldata,
                    uint256 scheduleTime,
                    bytes32 txHash
                ) = _storage.getTransaction(_proposalId, tid);
                if (txHash.length > 0 && _timeLock.queuedTransaction(txHash)) {
                    _timeLock.cancelTransaction(target, value, signature, _calldata, scheduleTime);
                }
            }
        }
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    /// @notice return the version of this implementation
    /// @return uint32 version number
    function version() external pure virtual returns (uint32) {
        return VERSION_1;
    }

    /// @notice return the name of the community
    /// @return bytes32 the community name
    function community() external view returns (bytes32) {
        return _storage.community();
    }

    /// @notice return the community url
    /// @return string memory representation of url
    function url() external view returns (string memory) {
        return _storage.url();
    }

    /// @notice return community description
    /// @return string memory representation of community description
    function description() external view returns (string memory) {
        return _storage.description();
    }

    function castVoteFor(uint256 _proposalId, uint256 _tokenId) private {
        uint256 count = _storage.voteForByShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteCount(_proposalId, msg.sender, _tokenId, count, 0);
        } else {
            revert("Not voter");
        }
    }

    function castVoteAgainst(uint256 _proposalId, uint256 _tokenId) private {
        uint256 count = _storage.voteAgainstByShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteCount(_proposalId, msg.sender, _tokenId, 0, count);
        } else {
            revert("Not voter");
        }
    }

    function castAbstention(uint256 _proposalId, uint256 _tokenId) private {
        uint256 count = _storage.abstainForShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteCount(_proposalId, msg.sender, _tokenId, 0, 0);
        } else {
            revert("Not voter");
        }
    }

    function _undoVote(uint256 _proposalId, uint256 _tokenId) private {
        uint256 count = _storage.undoVoteById(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteUndo(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    function sendGasRebate(address recipient, uint256 startGas) internal {
        uint256 balance = getRebateBalance();
        if (balance == 0) {
            return;
        }
        // determine rebate and transfer
        (uint256 rebate, uint256 gasUsed) = calculateGasRebate(startGas, balance);
        payable(recipient).transfer(rebate);
        emit RebatePaid(recipient, rebate, gasUsed);
    }

    function calculateGasRebate(uint256 startGas, uint256 balance) private view returns (uint256 rebate, uint256 gasUsed) {
        uint256 permittedBaseFee = Math.min(block.basefee, _maximumBaseFeeRebate);
        uint256 permittedGasPrice = Math.min(tx.gasprice, permittedBaseFee + Constant.MAXIMUM_REBATE_PRIORITY_FEE);

        uint256 totalGasUsed = startGas - gasleft();

        uint256 gasUsedForRebate = Math.min(totalGasUsed + Constant.REBATE_BASE_GAS, _maximumGasUsedRebate);
        uint256 rebateQuantity = Math.min(permittedGasPrice * gasUsedForRebate, balance);
        return (rebateQuantity, totalGasUsed);
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    function getRebateBalance() internal view returns (uint256) {
        return address(this).balance;
    }
}
