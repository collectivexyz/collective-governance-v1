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

import "../contracts/Constant.sol";
import "../contracts/storage/Storage.sol";
import "../contracts/storage/MetaStorage.sol";
import "../contracts/Governance.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/community/VoterClass.sol";
import "../contracts/treasury/TimeLocker.sol";
import "../contracts/treasury/TimeLock.sol";
import "../contracts/access/Versioned.sol";
import "../contracts/access/VersionedContract.sol";

/// @notice bounded gas rebate calculation
/// @param startGas the initial value of gasleft() function
/// @param balance maximum balance of WEI to spend
/// @param _maximumBaseFeeRebate maximum base fee rebate
/// @param _maximumGasUsedRebate maximum gas used
/// @return rebate The rebate
/// @return gasUsed The total gas used from gasleft to this call
// solhint-disable-next-line func-visibility
function calculateGasRebate(
    uint256 startGas,
    uint256 balance,
    uint256 _maximumBaseFeeRebate,
    uint256 _maximumGasUsedRebate
) view returns (uint256 rebate, uint256 gasUsed) {
    uint256 permittedBaseFee = Math.min(block.basefee, _maximumBaseFeeRebate);
    uint256 permittedGasPrice = Math.min(tx.gasprice, permittedBaseFee + Constant.MAXIMUM_REBATE_PRIORITY_FEE);

    uint256 totalGasUsed = startGas - gasleft();

    uint256 gasUsedForRebate = Math.min(totalGasUsed + Constant.REBATE_BASE_GAS, _maximumGasUsedRebate);
    uint256 rebateQuantity = Math.min(permittedGasPrice * gasUsedForRebate, balance);
    return (rebateQuantity, totalGasUsed);
}

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
contract CollectiveGovernance is VoteStrategy, Governance, ERC165, VersionedContract {
    string public constant NAME = "collective governance";

    VoterClass public immutable _voterClass;

    Storage public immutable _storage;

    TimeLocker public immutable _timeLock;

    uint256 public immutable _maximumGasUsedRebate;

    uint256 public immutable _maximumBaseFeeRebate;

    address[] private _communitySupervisorList;

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
    constructor(
        address[] memory _supervisorList,
        VoterClass _class,
        Storage _governanceStorage,
        TimeLocker _timeLocker,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate
    ) {
        if (_supervisorList.length == 0) revert SupervisorListEmpty();
        if (_gasUsedRebate < Constant.MAXIMUM_REBATE_GAS_USED)
            revert GasUsedRebateMustBeLarger(_gasUsedRebate, Constant.MAXIMUM_REBATE_GAS_USED);
        if (_baseFeeRebate < Constant.MAXIMUM_REBATE_BASE_FEE)
            revert BaseFeeRebateMustBeLarger(_baseFeeRebate, Constant.MAXIMUM_REBATE_BASE_FEE);
        _voterClass = _class;
        _storage = _governanceStorage;
        _timeLock = _timeLocker;
        _maximumGasUsedRebate = _gasUsedRebate;
        _maximumBaseFeeRebate = _baseFeeRebate;
        _communitySupervisorList = _supervisorList;
    }

    modifier requireNotFinal(uint256 _proposalId) {
        if (_storage.isFinal(_proposalId)) revert VoteFinal(_proposalId);
        _;
    }

    modifier requireVoteFinal(uint256 _proposalId) {
        if (!_storage.isFinal(_proposalId)) revert VoteNotFinal(_proposalId);
        _;
    }

    modifier requireVoteClosed(uint256 _proposalId) {
        if (isVoteOpenByProposalId[_proposalId]) revert VoteIsOpen(_proposalId);
        _;
    }

    modifier requireVoteOpen(uint256 _proposalId) {
        if (!isVoteOpenByProposalId[_proposalId]) revert VoteIsClosed(_proposalId);
        _;
    }

    modifier requireVoteAccepted(uint256 _proposalId) {
        if (_storage.isCancel(_proposalId)) revert VoteCancelled(_proposalId);
        if (_storage.isVeto(_proposalId)) revert VoteVetoed(_proposalId);
        _;
    }

    modifier requireSupervisor(uint256 _proposalId) {
        if (!_storage.isSupervisor(_proposalId, msg.sender)) revert NotSupervisor(_proposalId, msg.sender);
        _;
    }

    modifier requireSender(uint256 _proposalId) {
        if (_storage.getSender(_proposalId) != msg.sender) revert Storage.NotSender(_proposalId, msg.sender);
        _;
    }

    // @dev recieve funds for the purpose of offering a rebate on gas fees
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
        return _proposeVote(msg.sender);
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
    ) external requireSender(_proposalId) returns (uint256) {
        Transaction memory _transaction = Transaction(_target, _value, _signature, _calldata, _scheduleTime);
        bytes32 txHash = _timeLock.queueTransaction(
            _transaction.target,
            _transaction.value,
            _transaction.signature,
            _transaction._calldata,
            _transaction.scheduleTime
        );
        uint256 transactionId = _storage.addTransaction(_proposalId, _transaction, msg.sender);
        emit ProposalTransactionAttached(
            msg.sender,
            _proposalId,
            transactionId,
            _transaction.target,
            _transaction.value,
            _transaction.scheduleTime,
            txHash
        );
        return transactionId;
    }

    /// @notice set a choice by choice id
    /// @dev requires supervisor
    /// @param _proposalId the id of the proposal
    /// @param _name the name of the metadata field
    /// @param _description the detailed description of the choice
    /// @param _transactionId The id of the transaction to execute
    function addChoice(
        uint256 _proposalId,
        bytes32 _name,
        string memory _description,
        uint256 _transactionId
    ) external requireSender(_proposalId) returns (uint256) {
        Choice memory choice = Choice(_name, _description, _transactionId, "", 0);
        uint256 _choiceId = _storage.addChoice(_proposalId, choice, msg.sender);
        emit ProposalChoice(_proposalId, _choiceId, _name, _description, _transactionId);
        return _choiceId;
    }

    /// @notice configure an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _quorumRequired The threshold of participation that is required for a successful conclusion of voting
    function configure(uint256 _proposalId, uint256 _quorumRequired) public requireSupervisor(_proposalId) {
        address _sender = msg.sender;
        _storage.setQuorumRequired(_proposalId, _quorumRequired, _sender);
        _storage.makeFinal(_proposalId, _sender);
        emit ProposalFinal(_proposalId, _quorumRequired);
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
        emit ProposalDelay(_requiredDelay, _requiredDuration);
    }

    /// @notice start the voting process by proposal id
    /// @param _proposalId The numeric id of the proposed vote
    function startVote(uint256 _proposalId) external requireVoteFinal(_proposalId) requireVoteAccepted(_proposalId) {
        if (_storage.quorumRequired(_proposalId) == Constant.UINT_MAX) revert QuorumNotConfigured(_proposalId);
        if (isVoteOpenByProposalId[_proposalId]) revert VoteIsOpen(_proposalId);
        isVoteOpenByProposalId[_proposalId] = true;
        emit VoteOpen(_proposalId);
    }

    /// @notice test if an existing proposal is open
    /// @param _proposalId The numeric id of the proposed vote
    /// @return bool True if the proposal is open
    function isOpen(uint256 _proposalId) external view returns (bool) {
        uint256 endTime = _storage.endTime(_proposalId);
        bool voteProceeding = !_storage.isCancel(_proposalId) && !_storage.isVeto(_proposalId);
        return isVoteOpenByProposalId[_proposalId] && getBlockTimestamp() < endTime && voteProceeding;
    }

    /// @notice end voting on an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev it is not possible to end voting until the required duration has elapsed
    function endVote(uint256 _proposalId) public requireVoteOpen(_proposalId) {
        uint256 _endTime = _storage.endTime(_proposalId);
        if (_endTime > getBlockTimestamp() && !_storage.isVeto(_proposalId) && !_storage.isCancel(_proposalId))
            revert VoteInProgress(_proposalId);
        isVoteOpenByProposalId[_proposalId] = false;
        if (!_storage.isVeto(_proposalId) && getVoteSucceeded(_proposalId)) {
            executeTransaction(_proposalId);
        } else {
            cancelTransaction(_proposalId);
        }
        emit VoteClosed(_proposalId);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _choiceId The choice to vote for
    function voteChoice(
        uint256 _proposalId,
        uint256 _choiceId
    ) public requireVoteFinal(_proposalId) requireVoteOpen(_proposalId) requireVoteAccepted(_proposalId) {
        uint256 startGas = gasleft();
        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        for (uint256 i = 0; i < _shareList.length; i++) {
            _castVoteFor(_proposalId, _shareList[i], _choiceId);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev Auto discovery is attempted and if possible the method will proceed using the discovered shares
    function voteFor(uint256 _proposalId) external {
        voteChoice(_proposalId, 0);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _shareList A array of tokens or shares that confer the right to vote
    function voteFor(uint256 _proposalId, uint256[] memory _shareList) external {
        voteFor(_proposalId, _shareList, 0);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenIdList A array of tokens or shares that confer the right to vote
    /// @param _choiceId The choice to vote for
    function voteFor(
        uint256 _proposalId,
        uint256[] memory _tokenIdList,
        uint256 _choiceId
    ) public requireVoteFinal(_proposalId) requireVoteOpen(_proposalId) requireVoteAccepted(_proposalId) {
        uint256 startGas = gasleft();
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            _castVoteFor(_proposalId, _tokenIdList[i], _choiceId);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function voteFor(uint256 _proposalId, uint256 _tokenId) external {
        voteFor(_proposalId, _tokenId, 0);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    /// @param _choiceId The choice to vote for
    function voteFor(
        uint256 _proposalId,
        uint256 _tokenId,
        uint256 _choiceId
    ) public requireVoteFinal(_proposalId) requireVoteOpen(_proposalId) requireVoteAccepted(_proposalId) {
        uint256 startGas = gasleft();
        _castVoteFor(_proposalId, _tokenId, _choiceId);
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an against vote by id
    /// @dev auto discovery is attempted and if possible the method will proceed using the discovered shares
    /// @param _proposalId The numeric id of the proposed vote
    function voteAgainst(
        uint256 _proposalId
    ) external requireVoteFinal(_proposalId) requireVoteOpen(_proposalId) requireVoteAccepted(_proposalId) {
        uint256 startGas = gasleft();
        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        for (uint256 i = 0; i < _shareList.length; i++) {
            _castVoteAgainst(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an against vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _shareList A array of tokens or shares that confer the right to vote
    function voteAgainst(
        uint256 _proposalId,
        uint256[] memory _shareList
    ) external requireVoteFinal(_proposalId) requireVoteOpen(_proposalId) requireVoteAccepted(_proposalId) {
        uint256 startGas = gasleft();
        for (uint256 i = 0; i < _shareList.length; i++) {
            _castVoteAgainst(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice cast an against vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function voteAgainst(
        uint256 _proposalId,
        uint256 _tokenId
    ) external requireVoteFinal(_proposalId) requireVoteOpen(_proposalId) requireVoteAccepted(_proposalId) {
        uint256 startGas = gasleft();
        _castVoteAgainst(_proposalId, _tokenId);
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice abstain from vote by id
    /// @dev auto discovery is attempted and if possible the method will proceed using the discovered shares
    /// @param _proposalId The numeric id of the proposed vote
    function abstainFrom(
        uint256 _proposalId
    ) external requireVoteFinal(_proposalId) requireVoteOpen(_proposalId) requireVoteAccepted(_proposalId) {
        uint256 startGas = gasleft();
        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        for (uint256 i = 0; i < _shareList.length; i++) {
            _castAbstention(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice abstain from vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _shareList A array of tokens or shares that confer the right to vote
    function abstainFrom(
        uint256 _proposalId,
        uint256[] memory _shareList
    ) external requireVoteFinal(_proposalId) requireVoteOpen(_proposalId) requireVoteAccepted(_proposalId) {
        uint256 startGas = gasleft();
        for (uint256 i = 0; i < _shareList.length; i++) {
            _castAbstention(_proposalId, _shareList[i]);
        }
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice abstain from vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function abstainFrom(
        uint256 _proposalId,
        uint256 _tokenId
    ) external requireVoteFinal(_proposalId) requireVoteOpen(_proposalId) requireVoteAccepted(_proposalId) {
        uint256 startGas = gasleft();
        _castAbstention(_proposalId, _tokenId);
        sendGasRebate(msg.sender, startGas);
    }

    /// @notice veto proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev transaction must be signed by a supervisor wallet
    function veto(
        uint256 _proposalId
    )
        external
        requireSupervisor(_proposalId)
        requireVoteFinal(_proposalId)
        requireVoteOpen(_proposalId)
        requireVoteAccepted(_proposalId)
    {
        _storage.veto(_proposalId, msg.sender);
        emit ProposalVeto(_proposalId, msg.sender);
    }

    /// @notice get the result of the vote
    /// @return bool True if the vote is closed and passed
    /// @dev This method will fail if the vote was vetoed
    function getVoteSucceeded(
        uint256 _proposalId
    ) public view requireVoteAccepted(_proposalId) requireVoteFinal(_proposalId) requireVoteClosed(_proposalId) returns (bool) {
        uint256 totalVotesCast = _storage.quorum(_proposalId);
        bool quorumRequirementMet = totalVotesCast >= _storage.quorumRequired(_proposalId);
        return
            quorumRequirementMet &&
            ((_storage.forVotes(_proposalId) > _storage.againstVotes(_proposalId)) || _storage.isChoiceVote(_proposalId));
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(Governance).interfaceId ||
            interfaceId == type(VoteStrategy).interfaceId ||
            interfaceId == type(Versioned).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice cancel a proposal if it is not yet open
    /// @dev proposal must be finalized and ready but voting must not yet be open
    /// @param _proposalId The numeric id of the proposed vote
    function cancel(uint256 _proposalId) public requireSupervisor(_proposalId) {
        uint256 _startTime = _storage.startTime(_proposalId);
        if (isVoteOpenByProposalId[_proposalId] || getBlockTimestamp() > _startTime)
            revert CancelNotPossible(_proposalId, msg.sender);
        uint256 transactionCount = _storage.transactionCount(_proposalId);
        for (uint256 tid = 0; tid < transactionCount; tid++) {
            Transaction memory transaction = _storage.getTransaction(_proposalId, tid);
            _timeLock.cancelTransaction(
                transaction.target,
                transaction.value,
                transaction.signature,
                transaction._calldata,
                transaction.scheduleTime
            );
            _storage.clearTransaction(_proposalId, tid, msg.sender);
            emit ProposalTransactionCancelled(
                _proposalId,
                tid,
                transaction.target,
                transaction.value,
                transaction.scheduleTime,
                getHash(transaction)
            );
        }
        _storage.cancel(_proposalId, msg.sender);
    }

    function executeTransaction(uint256 _proposalId) private {
        if (_storage.isExecuted(_proposalId)) revert TransactionExecuted(_proposalId);
        _storage.setExecuted(_proposalId);
        uint256 transactionCount = _storage.transactionCount(_proposalId);
        if (transactionCount > 0) {
            uint256 executedCount = 0;
            if (_storage.isChoiceVote(_proposalId)) {
                uint256 winningChoice = _storage.getWinningChoice(_proposalId);
                if (winningChoice == 0 || winningChoice > _storage.choiceCount(_proposalId))
                    revert InvalidChoice(_proposalId, winningChoice);
                Choice memory choice = _storage.getChoice(_proposalId, winningChoice);
                if (choice.transactionId > 0) {
                    executeTransaction(_proposalId, choice.transactionId, choice.txHash);
                    executedCount++;
                }

                emit WinningChoice(_proposalId, choice.name, choice.description, choice.transactionId, choice.voteCount);
            } else {
                for (uint256 transactionId = 1; transactionId <= transactionCount; transactionId++) {
                    executeTransaction(_proposalId, transactionId, "");
                    executedCount++;
                }
            }
            emit ProposalExecuted(_proposalId, executedCount);
        }
    }

    function executeTransaction(uint256 _proposalId, uint256 _transactionId, bytes32 _txHash) private {
        Transaction memory transaction = _storage.getTransaction(_proposalId, _transactionId);
        bytes32 txHash = getHash(transaction);
        if (_txHash != 0x0 && txHash != _txHash) revert TransactionSignatureNotMatching(_proposalId, _transactionId);
        if (txHash.length > 0 && _timeLock.queuedTransaction(txHash)) {
            _timeLock.executeTransaction(
                transaction.target,
                transaction.value,
                transaction.signature,
                transaction._calldata,
                transaction.scheduleTime
            );
            emit ProposalTransactionExecuted(
                _proposalId,
                _transactionId,
                transaction.target,
                transaction.value,
                transaction.scheduleTime,
                txHash
            );
        }
    }

    function cancelTransaction(uint256 _proposalId) private {
        uint256 transactionCount = _storage.transactionCount(_proposalId);
        if (transactionCount > 0) {
            for (uint256 tid = 1; tid <= transactionCount; tid++) {
                Transaction memory transaction = _storage.getTransaction(_proposalId, tid);
                bytes32 txHash = getHash(transaction);
                if (txHash.length > 0 && _timeLock.queuedTransaction(txHash)) {
                    _timeLock.cancelTransaction(
                        transaction.target,
                        transaction.value,
                        transaction.signature,
                        transaction._calldata,
                        transaction.scheduleTime
                    );
                }
            }
        }
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    function sendGasRebate(address recipient, uint256 startGas) internal {
        uint256 balance = getRebateBalance();
        if (balance == 0) {
            return;
        }
        // determine rebate and transfer
        (uint256 rebate, uint256 gasUsed) = calculateGasRebate(startGas, balance, _maximumBaseFeeRebate, _maximumGasUsedRebate);
        payable(recipient).transfer(rebate);
        emit RebatePaid(recipient, rebate, gasUsed);
    }

    function _proposeVote(address _sender) private returns (uint256) {
        if (!_voterClass.canPropose(_sender)) revert NotPermitted(_sender);
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

    function _castVoteFor(uint256 _proposalId, uint256 _tokenId, uint256 _choiceId) internal {
        uint256 voteCount = 0;
        voteCount = _storage.voteForByShare(_proposalId, msg.sender, _tokenId, _choiceId);
        if (voteCount > 0) {
            emit VoteStrategy.VoteCount(_proposalId, msg.sender, _tokenId, voteCount, 0);
        } else {
            revert VoteStrategy.NotVoter(_proposalId, msg.sender);
        }
    }

    function _castVoteAgainst(uint256 _proposalId, uint256 _tokenId) internal {
        uint256 count = _storage.voteAgainstByShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteStrategy.VoteCount(_proposalId, msg.sender, _tokenId, 0, count);
        } else {
            revert VoteStrategy.NotVoter(_proposalId, msg.sender);
        }
    }

    function _castAbstention(uint256 _proposalId, uint256 _tokenId) internal {
        uint256 count = _storage.abstainForShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteStrategy.VoteCount(_proposalId, msg.sender, _tokenId, 0, 0);
        } else {
            revert VoteStrategy.NotVoter(_proposalId, msg.sender);
        }
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    function getRebateBalance() internal view returns (uint256) {
        return address(this).balance;
    }
}
