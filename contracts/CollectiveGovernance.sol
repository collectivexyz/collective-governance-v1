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
import "../contracts/GovernanceStorage.sol";
import "../contracts/Governance.sol";
import "../contracts/VoteStrategy.sol";

/// @title CollectiveGovernance
// factory contract for governance
contract CollectiveGovernance is Governance, VoteStrategy {
    /// @notice contract name
    string public constant name = "collective.xyz governance";
    uint32 public constant VERSION_1 = 1;

    Storage private _storage;

    /// @notice voting is open or not
    mapping(uint256 => bool) isVoteOpenByProposalId;

    address[] _projectSupervisorList = new address[](1);

    constructor() {
        _storage = new GovernanceStorage();
        _projectSupervisorList[0] = address(this);
    }

    modifier requireVoteOpen(uint256 _proposalId) {
        require(_storage.isReady(_proposalId) && isVoteOpenByProposalId[_proposalId], "Voting is closed");
        _;
    }

    modifier requireNoVeto(uint256 _proposalId) {
        require(!_storage.isVeto(_proposalId), "Vote is veto");
        _;
    }

    modifier requireVoteReady(uint256 _proposalId) {
        require(_storage.isReady(_proposalId) && !_storage.isVeto(_proposalId), "Voting is not ready");
        _;
    }

    modifier requireVoteClosed(uint256 _proposalId) {
        require(
            _storage.isReady(_proposalId) && !isVoteOpenByProposalId[_proposalId] && !_storage.isVeto(_proposalId),
            "Voting is not closed"
        );
        _;
    }

    modifier requireElectorSupervisor(uint256 _proposalId) {
        require(_storage.isSupervisor(_proposalId, msg.sender), "Elector supervisor required");
        _;
    }

    function version() public pure virtual returns (uint32) {
        return VERSION_1;
    }

    function getStorageAddress() external view returns (address) {
        return address(_storage);
    }

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

    function configure(
        uint256 _proposalId,
        uint256 _quorumThreshold,
        address _erc721,
        uint256 _requiredDuration
    ) external requireElectorSupervisor(_proposalId) {
        address _sender = msg.sender;
        _storage.setQuorumThreshold(_proposalId, _quorumThreshold, _sender);
        _storage.setRequiredVoteDuration(_proposalId, _requiredDuration, _sender);
        _storage.registerVoterClassERC721(_proposalId, _erc721, _sender);
        _storage.makeReady(_proposalId, _sender);
        this.openVote(_proposalId);
        emit ProposalOpen(_proposalId);
    }

    /// @notice allow voting
    function openVote(uint256 _proposalId) public requireElectorSupervisor(_proposalId) requireVoteReady(_proposalId) {
        _storage.validOrRevert(_proposalId);
        require(_storage.quorumRequired(_proposalId) < _storage.maxPassThreshold(), "Quorum must be set prior to opening vote");
        if (!isVoteOpenByProposalId[_proposalId]) {
            isVoteOpenByProposalId[_proposalId] = true;
            emit VoteOpen(_proposalId);
        } else {
            revert("Already open");
        }
    }

    function isOpen(uint256 _proposalId) public view returns (bool) {
        _storage.validOrRevert(_proposalId);
        uint256 endBlock = _storage.endBlock(_proposalId);
        return isVoteOpenByProposalId[_proposalId] && block.number < endBlock;
    }

    /// @notice forbid any further voting
    function endVote(uint256 _proposalId) public requireElectorSupervisor(_proposalId) requireVoteOpen(_proposalId) {
        _storage.validOrRevert(_proposalId);
        if (!_storage.isReady(_proposalId)) {
            _storage.makeReady(_proposalId, msg.sender);
        }
        uint256 _endBlock = _storage.endBlock(_proposalId);
        require(_endBlock < block.number, "Voting remains active");
        isVoteOpenByProposalId[_proposalId] = false;
        emit VoteClosed(_proposalId);
        emit ProposalClosed(_proposalId);
    }

    /// @notice veto the current measure
    function veto(uint256 _proposalId)
        public
        requireElectorSupervisor(_proposalId)
        requireVoteOpen(_proposalId)
        requireNoVeto(_proposalId)
    {
        _storage.veto(_proposalId, msg.sender);
    }

    // @notice cast an affirmative vote for the measure
    function voteFor(uint256 _proposalId) public requireVoteOpen(_proposalId) requireNoVeto(_proposalId) {
        VoterClass _class = _storage.voterClass(_proposalId);
        uint256[] memory _shareList = _class.discover(msg.sender);
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

    function voteForWithTokenId(uint256 _proposalId, uint256 _tokenId)
        public
        requireVoteOpen(_proposalId)
        requireNoVeto(_proposalId)
    {
        uint256 count = _storage.voteForByShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    // @notice undo any previous vote
    function undoVote(uint256 _proposalId) public requireVoteOpen(_proposalId) requireNoVeto(_proposalId) {
        VoterClass _class = _storage.voterClass(_proposalId);
        uint256[] memory _shareList = _class.discover(msg.sender);
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

    function undoWithTokenId(uint256 _proposalId, uint256 _tokenId)
        public
        requireVoteOpen(_proposalId)
        requireNoVeto(_proposalId)
    {
        uint256 count = _storage.undoVoteById(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteUndo(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    function voteAgainst(uint256 _proposalId) public requireVoteOpen(_proposalId) requireNoVeto(_proposalId) {
        VoterClass _class = _storage.voterClass(_proposalId);
        uint256[] memory _shareList = _class.discover(msg.sender);
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

    function voteAgainstWithTokenId(uint256 _proposalId, uint256 _tokenId)
        public
        requireVoteOpen(_proposalId)
        requireNoVeto(_proposalId)
    {
        uint256 count = _storage.voteAgainstByShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit VoteTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    function abstainFromVote(uint256 _proposalId) public requireVoteOpen(_proposalId) requireNoVeto(_proposalId) {
        VoterClass _class = _storage.voterClass(_proposalId);
        uint256[] memory _shareList = _class.discover(msg.sender);
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

    function abstainWithTokenId(uint256 _proposalId, uint256 _tokenId)
        public
        requireVoteOpen(_proposalId)
        requireNoVeto(_proposalId)
    {
        uint256 count = _storage.abstainForShare(_proposalId, msg.sender, _tokenId);
        if (count > 0) {
            emit AbstentionTally(_proposalId, msg.sender, count);
        } else {
            revert("Not voter");
        }
    }

    /// @notice get the result of the measure pass or failed
    function getVoteSucceeded(uint256 _proposalId)
        public
        view
        requireVoteClosed(_proposalId)
        requireNoVeto(_proposalId)
        returns (bool)
    {
        _storage.validOrRevert(_proposalId);
        uint256 totalVotesCast = _storage.quorum(_proposalId);
        require(totalVotesCast >= _storage.quorumRequired(_proposalId), "Not enough participants");
        return _storage.forVotes(_proposalId) > _storage.againstVotes(_proposalId);
    }
}
