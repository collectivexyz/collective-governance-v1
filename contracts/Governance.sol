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

/// @title Governance
/// contract enables proposing a measure to be voted upon
interface Governance {
    event StorageAddress(address _storage);
    event StrategyAddress(address strategy, uint32 version);
    event ProposalCreated(address proposer, uint256 proposalId);
    event ProposalOpen(uint256 proposalId);
    event ProposalClosed(uint256 proposalId);

    /// @notice propose a measurement of a vote class @returns proposal id
    function propose() external returns (uint256);

    function configure(
        uint256 proposalId,
        uint256 quorumThreshold,
        address erc721,
        uint256 requiredDuration
    ) external;

    function name() external pure returns (string memory);

    function version() external pure returns (uint32);

    function endVote(uint256 _proposalId) external;

    function voteFor(uint256 _proposalId) external;

    function voteAgainst(uint256 _proposalId) external;

    function abstainFromVote(uint256 _proposalId) external;

    function voteSucceeded(uint256 _proposalId) external view returns (bool);

    function getCurrentStrategyVersion() external view returns (uint32);

    function getCurrentStrategyAddress() external view returns (address);

    function getStorageAddress() external view returns (address);

}
