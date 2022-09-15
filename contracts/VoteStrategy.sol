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

import "./VoterClass.sol";
import "./VoterClassNullObject.sol";

/// @title VoteStrategy
/// upgradable implementation of voting for Collective Governance
interface VoteStrategy {
    // event section
    event VoteOpen(uint256 proposalId);
    event VoteClosed(uint256 proposalId);
    event VoteTally(uint256 proposalId, address wallet, uint256 count);
    event AbstentionTally(uint256 proposalId, address wallet, uint256 count);
    event VoteUndo(uint256 proposalId, address wallet, uint256 count);

    function openVote(uint256 _proposalId) external;

    function endVote(uint256 _proposalId) external;

    function voteFor(uint256 _proposalId) external;

    function voteForWithTokenId(uint256 _proposalId, uint256 _tokenId) external;

    function voteForWithTokenList(uint256 _proposalId, uint256[] memory _tokenIdList) external;

    function voteAgainst(uint256 _proposalId) external;

    function voteAgainstWithTokenId(uint256 _proposalId, uint256 _tokenId) external;

    function voteAgainstWithTokenList(uint256 _proposalId, uint256[] memory _tokenIdList) external;

    function abstainFromVote(uint256 _proposalId) external;

    function abstainWithTokenId(uint256 _proposalId, uint256 _tokenId) external;

    function abstainWithTokenList(uint256 _proposalId, uint256[] memory _tokenIdList) external;

    function undoVote(uint256 _proposalId) external;

    function undoWithTokenId(uint256 _proposalId, uint256 _tokenId) external;

    function veto(uint256 _proposalId) external;

    function getVoteSucceeded(uint256 _proposalId) external view returns (bool);

    function isOpen(uint256 _proposalId) external view returns (bool);
}
