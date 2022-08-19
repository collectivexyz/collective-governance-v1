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
import "../contracts/ElectorVoterPoolStrategy.sol";

/// @title CollectiveGovernance
// factory contract for governance
contract CollectiveGovernance is Governance {
    /// @notice contract name
    string public constant name = "collective.xyz governance";
    uint32 public constant VERSION_1 = 1;

    Storage private _storage;
    VoteStrategy private _voteStrategy;

    constructor() {
        _storage = new GovernanceStorage();
        emit StorageAddress(address(_storage));
        _voteStrategy = new ElectorVoterPoolStrategy(_storage);
        emit StrategyAddress(address(_voteStrategy), _voteStrategy.version());
    }

    function getCurrentStrategyVersion() external view returns (uint32) {
        return _voteStrategy.version();
    }

    function getCurrentStrategyAddress() external view returns (address) {
        return address(_voteStrategy);
    }

    function getStorageAddress() external view returns (address) {
        return address(_storage);
    }

    function propose() external returns (uint256) {
        address owner = msg.sender;
        uint256 proposalId = _storage._initializeProposal(address(_voteStrategy));
        _storage.registerSupervisor(proposalId, owner);
        emit ProposalCreated(owner, proposalId);
        return proposalId;
    }

    function configure(
        uint256 _proposalId,
        uint256 _quorumThreshold,
        address _erc721,
        uint256 _requiredDuration
    ) external {
        _storage.setQuorumThreshold(_proposalId, _quorumThreshold);
        _storage.setRequiredVoteDuration(_proposalId, _requiredDuration);
        _storage.registerVoterClassERC721(_proposalId, _erc721);
        _storage.makeReady(_proposalId);
        _voteStrategy.openVote(_proposalId);
        emit ProposalOpen(_proposalId);
    }

    function endVote(uint256 _proposalId) external {
        address _strategyAddress = _storage.voteStrategy(_proposalId);
        VoteStrategy _strategy = VoteStrategy(_strategyAddress);
        _strategy.endVote(_proposalId);
        emit ProposalClosed(_proposalId);
    }

    function voteFor(uint256 _proposalId) external {
        address _strategyAddress = _storage.voteStrategy(_proposalId);
        VoteStrategy _strategy = VoteStrategy(_strategyAddress);
        _strategy.voteFor(_proposalId);
    }

    function voteAgainst(uint256 _proposalId) external {
        address _strategyAddress = _storage.voteStrategy(_proposalId);
        VoteStrategy _strategy = VoteStrategy(_strategyAddress);
        _strategy.voteAgainst(_proposalId);
    }

    function abstainFromVote(uint256 _proposalId) external {
        address _strategyAddress = _storage.voteStrategy(_proposalId);
        VoteStrategy _strategy = VoteStrategy(_strategyAddress);
        _strategy.abstainFromVote(_proposalId);
    }

    function voteSucceeded(uint256 _proposalId) external view returns (bool) {
        address _strategyAddress = _storage.voteStrategy(_proposalId);
        VoteStrategy _strategy = VoteStrategy(_strategyAddress);
        return _strategy.getVoteSucceeded(_proposalId);
    }

    function version() public pure virtual returns (uint32) {
        return VERSION_1;
    }
}
