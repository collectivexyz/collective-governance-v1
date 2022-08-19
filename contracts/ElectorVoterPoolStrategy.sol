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
import "../contracts/VoteStrategy.sol";

/// @title ElectorVoterPoolStrategy

// GovernorBravoDelegate.sol source code Copyright 2020 Compound Labs, Inc. licensed under the BSD-3-Clause license.
// NounsDAOLogicV1.sol source code Copyright 2020 Nounders DAO. licensed under the BSD-3-Clause license.
// This source code developed by Collective.xyz, Copyright 2022.

// a proposal is subject to approval by an elector voter pool, a specific group of supervisors has the authority to add and remove voters, to open and close voting
// and to veto the result of the vote as in the case of a failure of the election design

// modification to the vote and supervisor pools is only allowed prior to the opening of voting
// 'affirmative' vote must be cast by calling voteFor
// 'abstention' or 'negative' vote incurs no gas fees and every registered voter is default negative

// measure is considered passed when the threshold voter count is achieved out of the current voting pool

contract ElectorVoterPoolStrategy is VoteStrategy {
    /// @notice contract name
    string public constant name = "collective.xyz vote strategy";
    uint32 public constant VERSION_1 = 1;

    Storage private _storage;
    address private _owner;

    constructor(Storage _gstorage) {
        _storage = _gstorage;
        _owner = msg.sender;
    }

    /// @notice voting is open or not
    mapping(uint256 => bool) isVoteOpenByProposalId;

    modifier requireStrategyVersion(uint256 _proposalId) {
        address strategy = _storage.voteStrategy(_proposalId);
        require(address(this) == strategy, "Strategy not valid for this proposalId");
        _;
    }

    modifier requireVoteOpen(uint256 _proposalId) {
        require(
            _storage.isReady(_proposalId) && isVoteOpenByProposalId[_proposalId] && !_storage.isVeto(_proposalId),
            "Voting is closed."
        );
        _;
    }

    modifier requireVoteReady(uint256 _proposalId) {
        require(_storage.isReady(_proposalId) && !_storage.isVeto(_proposalId), "Voting is not ready.");
        _;
    }

    modifier requireVoteClosed(uint256 _proposalId) {
        require(
            _storage.isReady(_proposalId) && !isVoteOpenByProposalId[_proposalId] && !_storage.isVeto(_proposalId),
            "Voting is not closed."
        );
        _;
    }

    modifier requireElectorSupervisor(uint256 _proposalId) {
        require(_storage.isSupervisor(_proposalId, msg.sender), "Elector supervisor required");
        _;
    }

    /// @notice allow voting
    function openVote(uint256 _proposalId)
        public
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVoteReady(_proposalId)
    {
        _storage._validOrRevert(_proposalId);
        require(_storage.quorumRequired(_proposalId) < _storage._maxPassThreshold(), "Quorum must be set prior to opening vote");
        if (!isVoteOpenByProposalId[_proposalId]) {
            isVoteOpenByProposalId[_proposalId] = true;
            emit VoteOpen(_proposalId);
        } else {
            revert("Already open.");
        }
    }

    function isOpen(uint256 _proposalId) public view requireStrategyVersion(_proposalId) returns (bool) {
        _storage._validOrRevert(_proposalId);
        return isVoteOpenByProposalId[_proposalId];
    }

    /// @notice forbid any further voting
    function endVote(uint256 _proposalId)
        public
        requireStrategyVersion(_proposalId)
        requireElectorSupervisor(_proposalId)
        requireVoteOpen(_proposalId)
    {
        _storage._validOrRevert(_proposalId);
        uint256 _endBlock = _storage.endBlock(_proposalId);
        require(_endBlock < block.number, "Voting remains active");
        isVoteOpenByProposalId[_proposalId] = false;
        emit VoteClosed(_proposalId);
    }

    /// @notice veto the current measure
    function veto(uint256 _proposalId) public requireStrategyVersion(_proposalId) requireVoteOpen(_proposalId) {
        _storage._veto(_proposalId);
    }

    // @notice cast an affirmative vote for the measure
    function voteFor(uint256 _proposalId, address wallet)
        public
        requireStrategyVersion(_proposalId)
        requireVoteOpen(_proposalId)
    {
        _storage._castVoteFor(_proposalId, wallet);
    }

    // @notice undo any previous vote
    function undoVote(uint256 _proposalId, address wallet)
        public
        requireStrategyVersion(_proposalId)
        requireVoteOpen(_proposalId)
    {
        _storage._castVoteUndo(_proposalId, wallet);
    }

    function voteAgainst(uint256 _proposalId, address wallet)
        public
        requireStrategyVersion(_proposalId)
        requireVoteOpen(_proposalId)
    {
        _storage._castVoteAgainst(_proposalId, wallet);
    }

    function abstainFromVote(uint256 _proposalId, address wallet)
        public
        requireStrategyVersion(_proposalId)
        requireVoteOpen(_proposalId)
    {
        _storage._abstainFromVote(_proposalId, wallet);
    }

    /// @notice get the result of the measure pass or failed
    function getVoteSucceeded(uint256 _proposalId)
        public
        view
        requireStrategyVersion(_proposalId)
        requireVoteClosed(_proposalId)
        returns (bool)
    {
        _storage._validOrRevert(_proposalId);
        uint256 totalVotesCast = _storage.quorum(_proposalId);
        require(totalVotesCast >= _storage.quorumRequired(_proposalId), "Not enough participants");
        return _storage.forVotes(_proposalId) > _storage.againstVotes(_proposalId);
    }

    function version() public pure virtual returns (uint32) {
        return VERSION_1;
    }
}
