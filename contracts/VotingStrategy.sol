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

import "./VoterClass.sol";
import "./VoterClassNullObject.sol";

/// @title VotingStrategy
/// upgradable implementation of voting for Collective Governance
interface VotingStrategy {
    // event section
    event AddSupervisor(address supervisor);
    event BurnSupervisor(address supervisor);
    event RegisterVoter(address voter);
    event BurnVoter(address voter);
    event RegisterVoterClass();
    event BurnVoterClass();
    event SetRequiredParticipation(uint256 requiredParticipation);
    event SetQuorumThreshold(uint256 passThreshold);
    event VotingOpen();
    event VotingClosed();
    event VoteCast(address voter, uint256 totalVotesCast);
    event UndoVoteEnabled();
    event VoteVeto(address supervisor);

    function name() external pure returns (string memory);

    function version() external pure returns (uint32);

    function registerSupervisor(uint256 _proposalId, address _supervisor) external;

    function burnSupervisor(uint256 _proposalId, address _supervisor) external;

    function registerVoter(uint256 _proposalId, address _voter) external;

    function registerVoters(uint256 _proposalId, address[] memory _voter) external;

    function burnVoter(uint256 _proposalId, address _voter) external;

    function registerVoterClass(uint256 _proposalId, VoterClass _class) external;

    function burnVoterClass(uint256 _proposalId) external;

    function setQuorumThreshold(uint256 _proposalId, uint256 _passThreshold) external;

    function setRequiredParticipation(uint256 _proposalId, uint256 _voteTally) external;

    function setVoteDelay(uint256 _proposalId, uint256 _voteDelay) external;

    function setRequiredVoteDuration(uint256 _proposalId, uint256 _voteDuration) external;

    function openVoting(uint256 _proposalId) external;

    function endVoting(uint256 _proposalId) external;

    function voteFor(uint256 _proposalId) external;

    function voteAgainst(uint256 _proposalId) external;

    function abstainFromVote(uint256 _proposalId) external;

    function veto(uint256 _proposalId) external;

    function getVoteSucceeded(uint256 _proposalId) external returns (bool);
}
