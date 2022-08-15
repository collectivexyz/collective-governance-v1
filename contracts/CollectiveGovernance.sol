// SPDX-License-Identifier: BSD-3-Clause
/*
 * Copyright 2022 collective.xyz
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
pragma solidity ^0.8.15;

import "./GovernanceStorage.sol";
import "./Governance.sol";
import "./UpgradeableGovernance.sol";
import "./VoteStrategy.sol";
import "./ElectorVoterPoolStrategy.sol";

/// @title CollectiveGovernance
// factory contract for governance
contract CollectiveGovernance is UpgradeableGovernance, Governance {
    address private owner;

    Storage private _storage;
    VoteStrategy private _voteStrategy;

    constructor() {
        owner = msg.sender;
        _storage = new GovernanceStorage();
        _voteStrategy = new ElectorVoterPoolStrategy(_storage);
    }

    modifier requireContractOwner() {
        require(owner == msg.sender, "Not contract owner");
        _;
    }

    function setVoteStrategy(address _strategy) external requireContractOwner {
        uint32 version = _voteStrategy.version();
        _voteStrategy = VoteStrategy(_strategy);
        uint32 newVersion = _voteStrategy.version();
        emit StrategyChange(version, newVersion);
    }

    function getCurrentStrategyVersion() external view returns (uint32) {
        return _voteStrategy.version();
    }

    function getCurrentStrategyAddress() external view returns (address) {
        return address(_voteStrategy);
    }

    function propose(
        uint256 quorumThreshold,
        address erc721,
        uint256 requiredDuration
    ) external returns (uint256) {
        uint256 proposalId = _storage._initializeProposal(address(_voteStrategy));
        _storage.registerSupervisor(proposalId, msg.sender);
        _storage.setQuorumThreshold(proposalId, quorumThreshold);
        _storage.setRequiredVoteDuration(proposalId, requiredDuration);
        _storage.registerVoterClassERC721(proposalId, erc721);
        _storage.makeReady(proposalId);
        _voteStrategy.openVote(proposalId);
        return proposalId;
    }

    function endVote(uint256 _proposalId) external {
        address _strategyAddress = _storage.voteStrategy(_proposalId);
        VoteStrategy _strategy = VoteStrategy(_strategyAddress);
        _strategy.endVote(_proposalId);
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
}
