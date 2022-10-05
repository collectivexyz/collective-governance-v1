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
/// First, propose the vote.  Next, Configure the vote.  Finally, open the vote.
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

    TimeLock private immutable _timeLock;

    address[] private _projectSupervisorList;

    /// @notice voting is open or not
    mapping(uint256 => bool) private isVoteOpenByProposalId;

    /// @notice create a new collective governance contract
    /// @dev this should be invoked through the GovernanceBuilder
    /// @param _supervisorList the list of supervisors for this project
    /// @param _class the VoterClass for this project
    /// @param _governanceStorage The storage contract for this governance
    constructor(
        address[] memory _supervisorList,
        VoterClass _class,
        Storage _governanceStorage
    ) {
        _voterClass = _class;
        _storage = _governanceStorage;
        uint256 _timeLockDelay = max(_storage.minimumVoteDuration(), Constant.TIMELOCK_MINIMUM_DELAY);
        _timeLock = new TimeLock(_timeLockDelay);
        _projectSupervisorList = _supervisorList;
    }

    modifier requireVoteReady(uint256 _proposalId) {
        require(_storage.isFinal(_proposalId), "Voting is not ready");
        _;
    }

    modifier requireVoteClosed(uint256 _proposalId) {
        require(_storage.isFinal(_proposalId) && !isVoteOpenByProposalId[_proposalId], "Vote is not closed");
        _;
    }

    /// @notice propose a vote for the community
    /// @dev Only one new proposal is allowed per msg.sender
    /// @return uint256 The id of the new proposal
    function propose() external returns (uint256) {
        address _sender = msg.sender;
        uint256 proposalId = _storage.initializeProposal(_sender);
        _storage.registerSupervisor(proposalId, _sender, _sender);
        for (uint256 i = 0; i < _projectSupervisorList.length; i++) {
            _storage.registerSupervisor(proposalId, _projectSupervisorList[i], _sender);
        }
        emit ProposalCreated(_sender, proposalId);
        return proposalId;
    }

    /// @notice Attach a transaction to the specified proposal.
    ///         If successfull, it will be executed when voting is ended.
    /// if the vote is successful.
    /// @dev must be called prior to configuration
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
        _storage.revertNotValid(_proposalId);
        require(_storage.getSender(_proposalId) == msg.sender, "Not sender");
        uint256 transactionId = _storage.addTransaction(
            _proposalId,
            _target,
            _value,
            _signature,
            _calldata,
            _scheduleTime,
            msg.sender
        );
        bytes32 txHash = _timeLock.queueTransaction(_target, _value, _signature, _calldata, _scheduleTime);
        emit ProposalTransactionAttached(msg.sender, _proposalId, _target, _value, _scheduleTime, txHash);
        return transactionId;
    }

    /// @notice configure an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _quorumRequired The threshold of participation that is required for a successful conclusion of voting
    function configure(uint256 _proposalId, uint256 _quorumRequired) external {
        _storage.revertNotValid(_proposalId);
        revertNotSupervisor(_proposalId);
        address _sender = msg.sender;
        _storage.setQuorumRequired(_proposalId, _quorumRequired, _sender);
        _storage.makeFinal(_proposalId, _sender);
        emit ProposalOpen(_proposalId);
    }

    /// @notice configure an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _quorumThreshold The threshold of participation that is required for a successful conclusion of voting
    /// @param _requiredDuration The minimum time for voting to proceed before ending the vote is allowed
    function configure(
        uint256 _proposalId,
        uint256 _quorumThreshold,
        uint256 _requiredDuration
    ) external {
        address _sender = msg.sender;
        _storage.revertNotValid(_proposalId);
        revertNotSupervisor(_proposalId);

        _storage.setQuorumRequired(_proposalId, _quorumThreshold, _sender);
        _storage.setVoteDuration(_proposalId, _requiredDuration, _sender);
        _storage.makeFinal(_proposalId, _sender);
        emit ProposalOpen(_proposalId);
    }

    /// @notice start the voting process by proposal id
    /// @param _proposalId The numeric id of the proposed vote
    function startVote(uint256 _proposalId) external requireVoteReady(_proposalId) {
        _storage.revertNotValid(_proposalId);
        revertNotSupervisor(_proposalId);
        revertVoteNotAllowed(_proposalId);

        require(_storage.quorumRequired(_proposalId) < _storage.maxPassThreshold(), "Quorum required");
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
        _storage.revertNotValid(_proposalId);
        uint256 endTime = _storage.endTime(_proposalId);
        bool voteProceeding = !_storage.isCancel(_proposalId) && !_storage.isVeto(_proposalId);
        return isVoteOpenByProposalId[_proposalId] && getBlockTimestamp() < endTime && voteProceeding;
    }

    /// @notice end voting on an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev it is not possible to end voting until the required duration has elapsed
    function endVote(uint256 _proposalId) public {
        _storage.revertNotValid(_proposalId);
        revertNotSupervisor(_proposalId);
        revertVoteNotOpen(_proposalId);

        uint256 _endTime = _storage.endTime(_proposalId);
        require(_endTime <= getBlockTimestamp() || _storage.isVeto(_proposalId) || _storage.isCancel(_proposalId), "Vote open");
        isVoteOpenByProposalId[_proposalId] = false;

        uint256 transactionCount = _storage.transactionCount(_proposalId);
        if (transactionCount > 0 && !_storage.isVeto(_proposalId) && getVoteSucceeded(_proposalId)) {
            require(!_storage.isExecuted(_proposalId), "Double execution");
            _storage.setExecuted(_proposalId, msg.sender);
            for (uint256 tid = 0; tid < transactionCount; tid++) {
                (address target, uint256 value, string memory signature, bytes memory _calldata, uint256 scheduleTime) = _storage
                    .getTransaction(_proposalId, tid);
                _timeLock.executeTransaction(target, value, signature, _calldata, scheduleTime);
            }
            emit ProposalExecuted(_proposalId);
        } else {
            for (uint256 tid = 0; tid < transactionCount; tid++) {
                (address target, uint256 value, string memory signature, bytes memory _calldata, uint256 scheduleTime) = _storage
                    .getTransaction(_proposalId, tid);
                _timeLock.cancelTransaction(target, value, signature, _calldata, scheduleTime);
            }
        }
        emit VoteClosed(_proposalId);
        emit ProposalClosed(_proposalId);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev Auto discovery is attempted and if possible the method will proceed using the discovered shares
    function voteFor(uint256 _proposalId) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);

        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        uint256 count = 0;
        for (uint256 i = 0; i < _shareList.length; i++) {
            uint256 shareId = _shareList[i];
            count += _storage.voteForByShare(_proposalId, msg.sender, shareId);
        }
        if (count > 0) {
            emit VoteTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function voteFor(uint256 _proposalId, uint256 _tokenId) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);

        uint256 count = _storage.voteForByShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenIdList A array of tokens or shares that confer the right to vote
    function voteFor(uint256 _proposalId, uint256[] memory _tokenIdList) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);

        uint256 count = 0;
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            count += _storage.voteForByShare(_proposalId, msg.sender, _tokenIdList[i]);
        }
        if (count > 0) {
            emit VoteTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice cast an against vote by id
    /// @dev auto discovery is attempted and if possible the method will proceed using the discovered shares
    /// @param _proposalId The numeric id of the proposed vote
    function voteAgainst(uint256 _proposalId) public {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);

        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        uint256 count = 0;
        for (uint256 i = 0; i < _shareList.length; i++) {
            uint256 shareId = _shareList[i];
            count += _storage.voteAgainstByShare(_proposalId, msg.sender, shareId);
        }
        if (count > 0) {
            emit VoteTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice cast an against vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function voteAgainst(uint256 _proposalId, uint256 _tokenId) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);
        uint256 count = _storage.voteAgainstByShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice cast an against vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenIdList A array of tokens or shares that confer the right to vote
    function voteAgainst(uint256 _proposalId, uint256[] memory _tokenIdList) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);
        uint256 count = 0;
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            count += _storage.voteAgainstByShare(_proposalId, msg.sender, _tokenIdList[i]);
        }
        if (count > 0) {
            emit VoteTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice abstain from vote by id
    /// @dev auto discovery is attempted and if possible the method will proceed using the discovered shares
    /// @param _proposalId The numeric id of the proposed vote
    function abstainFrom(uint256 _proposalId) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);
        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        uint256 count = 0;
        for (uint256 i = 0; i < _shareList.length; i++) {
            uint256 shareId = _shareList[i];
            count = _storage.abstainForShare(_proposalId, msg.sender, shareId);
        }
        if (count > 0) {
            emit AbstentionTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice abstain from vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function abstainFrom(uint256 _proposalId, uint256 _tokenId) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);
        uint256 count = _storage.abstainForShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit AbstentionTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice abstain from vote by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenIdList A array of tokens or shares that confer the right to vote
    function abstainFrom(uint256 _proposalId, uint256[] memory _tokenIdList) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);
        uint256 count = 0;
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            count += _storage.abstainForShare(_proposalId, msg.sender, _tokenIdList[i]);
        }
        if (count > 0) {
            emit AbstentionTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice undo any previous vote if any
    /// @dev Only applies to affirmative vote.
    /// auto discovery is attempted and if possible the method will proceed using the discovered shares
    /// @param _proposalId The numeric id of the proposed vote
    function undoVote(uint256 _proposalId) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);
        uint256[] memory _shareList = _voterClass.discover(msg.sender);
        uint256 count = 0;
        for (uint256 i = 0; i < _shareList.length; i++) {
            uint256 shareId = _shareList[i];
            count += _storage.undoVoteById(_proposalId, msg.sender, shareId);
        }
        if (count > 0) {
            emit VoteUndo(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice undo any previous vote if any
    /// @dev only applies to affirmative vote
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _tokenId The id of a token or share representing the right to vote
    function undoVote(uint256 _proposalId, uint256 _tokenId) external {
        _storage.revertNotValid(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);
        uint256 count = _storage.undoVoteById(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteUndo(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice veto proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev transaction must be signed by a supervisor wallet
    function veto(uint256 _proposalId) external {
        _storage.revertNotValid(_proposalId);
        revertNotSupervisor(_proposalId);
        revertVoteNotOpen(_proposalId);
        revertVoteNotAllowed(_proposalId);

        _storage.veto(_proposalId, msg.sender);
    }

    /// @notice get the result of the vote
    /// @return bool True if the vote is closed and passed
    /// @dev This method will fail if the vote was vetoed
    function getVoteSucceeded(uint256 _proposalId) public view requireVoteClosed(_proposalId) returns (bool) {
        _storage.revertNotValid(_proposalId);
        revertVoteNotAllowed(_proposalId);
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
    function cancel(uint256 _proposalId) public {
        _storage.revertNotValid(_proposalId);
        revertNotSupervisor(_proposalId);
        uint256 _startTime = _storage.startTime(_proposalId);
        require(!isVoteOpenByProposalId[_proposalId] && getBlockTimestamp() <= _startTime, "Not possible");
        uint256 transactionCount = _storage.transactionCount(_proposalId);
        for (uint256 tid = 0; tid < transactionCount; tid++) {
            (address target, uint256 value, string memory signature, bytes memory _calldata, uint256 scheduleTime) = _storage
                .getTransaction(_proposalId, tid);
            _timeLock.cancelTransaction(target, value, signature, _calldata, scheduleTime);
        }
        _storage.cancel(_proposalId, msg.sender);
        emit ProposalClosed(_proposalId);
    }

    function revertVoteNotOpen(uint256 _proposalId) private view {
        require(_storage.isFinal(_proposalId) && isVoteOpenByProposalId[_proposalId], "Voting is closed");
    }

    function revertVoteNotAllowed(uint256 _proposalId) private view {
        require(!_storage.isCancel(_proposalId) && !_storage.isVeto(_proposalId), "Vote cancelled");
    }

    function revertNotSupervisor(uint256 _proposalId) private view {
        require(_storage.isSupervisor(_proposalId, msg.sender), "Supervisor required");
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

    function getBlockTimestamp() internal view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return a;
        }
        return b;
    }
}
