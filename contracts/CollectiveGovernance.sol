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

import "../contracts/Storage.sol";
import "../contracts/GovernanceStorage.sol";
import "../contracts/Governance.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/VoterClass.sol";
import "../contracts/VoterClassERC721.sol";
import "../contracts/VoterClassOpenVote.sol";

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
    string public constant NAME = "collective.xyz governance";
    uint32 public constant VERSION_1 = 1;

    VoterClass private immutable _voterClass;

    Storage private immutable _storage;

    address[] private _projectSupervisorList;

    /// @notice voting is open or not
    mapping(uint256 => bool) private isVoteOpenByProposalId;

    constructor(address[] memory _supervisorList, VoterClass _class) {
        _voterClass = _class;
        _projectSupervisorList = _supervisorList;
        require(_class.isFinal(), "Voter Class is modifiable");
        _storage = new GovernanceStorage(_voterClass);
    }

    modifier requireVoteOpen(uint256 _proposalId) {
        require(_storage.isFinal(_proposalId) && isVoteOpenByProposalId[_proposalId], "Voting is closed");
        _;
    }

    modifier requireVoteReady(uint256 _proposalId) {
        require(_storage.isFinal(_proposalId), "Voting is not ready");
        _;
    }

    modifier requireVoteAllowed(uint256 _proposalId) {
        require(!_storage.isCancel(_proposalId) && !_storage.isVeto(_proposalId), "Vote cancelled");
        _;
    }

    modifier requireVoteClosed(uint256 _proposalId) {
        require(_storage.isFinal(_proposalId) && !isVoteOpenByProposalId[_proposalId], "Vote is not closed");
        _;
    }

    modifier requireElectorSupervisor(uint256 _proposalId) {
        require(_storage.isSupervisor(_proposalId, msg.sender), "Supervisor required");
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

    /// @notice configure an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @param _quorumThreshold The threshold of participation that is required for a successful conclusion of voting
    /// @param _requiredDuration The minimum time for voting to proceed before ending the vote is allowed
    function configure(
        uint256 _proposalId,
        uint256 _quorumThreshold,
        uint256 _requiredDuration
    ) external requireElectorSupervisor(_proposalId) {
        address _sender = msg.sender;
        _storage.setQuorumThreshold(_proposalId, _quorumThreshold, _sender);
        _storage.setRequiredVoteDuration(_proposalId, _requiredDuration, _sender);
        _storage.makeFinal(_proposalId, _sender);
        emit ProposalOpen(_proposalId);
    }

    /// @notice open an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    function openVote(uint256 _proposalId)
        external
        requireElectorSupervisor(_proposalId)
        requireVoteReady(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        _storage.validOrRevert(_proposalId);
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
        _storage.validOrRevert(_proposalId);
        uint256 endTime = _storage.endTime(_proposalId);
        bool voteProceeding = !_storage.isCancel(_proposalId) && !_storage.isVeto(_proposalId);
        // solhint-disable-next-line not-rely-on-time
        return isVoteOpenByProposalId[_proposalId] && block.timestamp < endTime && voteProceeding;
    }

    /// @notice end voting on an existing proposal by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev it is not possible to end voting until the required duration has elapsed
    function endVote(uint256 _proposalId) public requireElectorSupervisor(_proposalId) requireVoteOpen(_proposalId) {
        _storage.validOrRevert(_proposalId);
        uint256 _endTime = _storage.endTime(_proposalId);
        // solhint-disable-next-line not-rely-on-time
        require(_endTime <= block.timestamp || _storage.isVeto(_proposalId) || _storage.isCancel(_proposalId), "Vote open");
        isVoteOpenByProposalId[_proposalId] = false;
        emit VoteClosed(_proposalId);
        emit ProposalClosed(_proposalId);
    }

    /// @notice cast an affirmative vote for the measure by id
    /// @param _proposalId The numeric id of the proposed vote
    /// @dev Auto discovery is attempted and if possible the method will proceed using the discovered shares
    function voteFor(uint256 _proposalId) external requireVoteOpen(_proposalId) requireVoteAllowed(_proposalId) {
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
    function voteFor(uint256 _proposalId, uint256 _tokenId)
        external
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
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
    function voteFor(uint256 _proposalId, uint256[] memory _tokenIdList)
        external
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
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
    function voteAgainst(uint256 _proposalId) public requireVoteOpen(_proposalId) requireVoteAllowed(_proposalId) {
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
    function voteAgainst(uint256 _proposalId, uint256 _tokenId)
        external
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
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
    function voteAgainst(uint256 _proposalId, uint256[] memory _tokenIdList)
        external
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
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
    function abstainFrom(uint256 _proposalId) external requireVoteOpen(_proposalId) requireVoteAllowed(_proposalId) {
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
    function abstainFrom(uint256 _proposalId, uint256 _tokenId)
        external
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
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
    function abstainFrom(uint256 _proposalId, uint256[] memory _tokenIdList)
        external
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
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
    function undoVote(uint256 _proposalId) external requireVoteOpen(_proposalId) requireVoteAllowed(_proposalId) {
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
    function undoVote(uint256 _proposalId, uint256 _tokenId)
        external
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
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
    function veto(uint256 _proposalId)
        external
        requireElectorSupervisor(_proposalId)
        requireVoteOpen(_proposalId)
        requireVoteAllowed(_proposalId)
    {
        _storage.veto(_proposalId, msg.sender);
    }

    /// @notice get the result of the vote
    /// @return bool True if the vote is closed and passed
    /// @dev This method will fail if the vote was vetoed
    function getVoteSucceeded(uint256 _proposalId)
        external
        view
        requireVoteAllowed(_proposalId)
        requireVoteClosed(_proposalId)
        returns (bool)
    {
        _storage.validOrRevert(_proposalId);
        uint256 totalVotesCast = _storage.quorum(_proposalId);
        require(totalVotesCast >= _storage.quorumRequired(_proposalId), "Not enough participants");
        return _storage.forVotes(_proposalId) > _storage.againstVotes(_proposalId);
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
    function cancel(uint256 _proposalId) public requireElectorSupervisor(_proposalId) {
        _storage.validOrRevert(_proposalId);
        uint256 _startTime = _storage.startTime(_proposalId);
        // solhint-disable-next-line not-rely-on-time
        require(!isVoteOpenByProposalId[_proposalId] && block.timestamp <= _startTime, "Not possible");
        if (!_storage.isReady(_proposalId)) {
            _storage.makeReady(_proposalId, msg.sender);
            emit ProposalOpen(_proposalId);
        }
        _storage.cancel(_proposalId, msg.sender);
        emit ProposalClosed(_proposalId);
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
}
