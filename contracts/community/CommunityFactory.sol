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
 * Copyright (c) 2023, collective
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

import "../../contracts/community/CommunityClassOpenVote.sol";
import "../../contracts/community/CommunityClassVoterPool.sol";
import "../../contracts/community/CommunityClassERC721.sol";
import "../../contracts/community/CommunityClassClosedERC721.sol";
import "../../contracts/community/CommunityClassProxy.sol";

// solhint-disable-next-line func-visibility
function upgradeOpenVote(
    address payable proxyAddress,
    uint256 weight,
    uint256 minimumProjectQuorum,
    uint256 minimumVoteDelay,
    uint256 maximumVoteDelay,
    uint256 minimumVoteDuration,
    uint256 maximumVoteDuration
) {
    CommunityClass _class = new CommunityClassOpenVote();
    WeightedCommunityClassProxy _proxy = WeightedCommunityClassProxy(proxyAddress);
    _proxy.upgrade(
        address(_class),
        weight,
        minimumProjectQuorum,
        minimumVoteDelay,
        maximumVoteDelay,
        minimumVoteDuration,
        maximumVoteDuration
    );
}

// solhint-disable-next-line func-visibility
function upgradeVoterPool(
    address payable proxyAddress,
    uint256 weight,
    uint256 minimumProjectQuorum,
    uint256 minimumVoteDelay,
    uint256 maximumVoteDelay,
    uint256 minimumVoteDuration,
    uint256 maximumVoteDuration
) {
    CommunityClass _class = new CommunityClassVoterPool();
    WeightedCommunityClassProxy _proxy = WeightedCommunityClassProxy(proxyAddress);
    _proxy.upgrade(
        address(_class),
        weight,
        minimumProjectQuorum,
        minimumVoteDelay,
        maximumVoteDelay,
        minimumVoteDuration,
        maximumVoteDuration
    );
}

// solhint-disable-next-line func-visibility
function upgradeErc721(
    address payable proxyAddress,
    uint256 weight,
    uint256 minimumProjectQuorum,
    uint256 minimumVoteDelay,
    uint256 maximumVoteDelay,
    uint256 minimumVoteDuration,
    uint256 maximumVoteDuration
) {
    CommunityClass _class = new CommunityClassERC721();
    ProjectCommunityClassProxy _proxy = ProjectCommunityClassProxy(proxyAddress);
    _proxy.upgrade(
        address(_class),
        weight,
        minimumProjectQuorum,
        minimumVoteDelay,
        maximumVoteDelay,
        minimumVoteDuration,
        maximumVoteDuration
    );
}

// solhint-disable-next-line func-visibility
function upgradeClosedErc721(
    address payable proxyAddress,
    uint256 weight,
    uint256 minimumProjectQuorum,
    uint256 minimumVoteDelay,
    uint256 maximumVoteDelay,
    uint256 minimumVoteDuration,
    uint256 maximumVoteDuration
) {
    CommunityClass _class = new CommunityClassClosedERC721();
    ProjectCommunityClassProxy _proxy = ProjectCommunityClassProxy(proxyAddress);
    _proxy.upgrade(
        address(_class),
        weight,
        minimumProjectQuorum,
        minimumVoteDelay,
        maximumVoteDelay,
        minimumVoteDuration,
        maximumVoteDuration
    );
}

/**
 * @title Weighted Class Factory
 * @notice small factory intended to reduce construction size impact for weighted community classes
 */
contract WeightedClassFactory {
    /// @notice create a new community class representing an open vote
    /// @param weight the weight of a single voting share
    /// @param minimumProjectQuorum the least possible quorum for any vote
    /// @param minimumVoteDelay the least possible vote delay
    /// @param maximumVoteDelay the least possible vote delay
    /// @param minimumVoteDuration the least possible voting duration
    /// @param maximumVoteDuration the least possible voting duration
    function createOpenVote(
        uint256 weight,
        uint256 minimumProjectQuorum,
        uint256 minimumVoteDelay,
        uint256 maximumVoteDelay,
        uint256 minimumVoteDuration,
        uint256 maximumVoteDuration
    ) external returns (WeightedCommunityClass) {
        CommunityClass _class = new CommunityClassOpenVote();
        ERC1967Proxy _proxy = new WeightedCommunityClassProxy(
            address(_class),
            weight,
            minimumProjectQuorum,
            minimumVoteDelay,
            maximumVoteDelay,
            minimumVoteDuration,
            maximumVoteDuration
        );
        ScheduledCommunityClass _proxyClass = ScheduledCommunityClass(address(_proxy));
        _proxyClass.transferOwnership(msg.sender);
        return _proxyClass;
    }

    /// @notice create a new community class representing a voter pool
    /// @param weight the weight of a single voting share
    /// @param minimumProjectQuorum the least possible quorum for any vote
    /// @param minimumVoteDelay the least possible vote delay
    /// @param maximumVoteDelay the least possible vote delay
    /// @param minimumVoteDuration the least possible voting duration
    /// @param maximumVoteDuration the least possible voting duration
    function createVoterPool(
        uint256 weight,
        uint256 minimumProjectQuorum,
        uint256 minimumVoteDelay,
        uint256 maximumVoteDelay,
        uint256 minimumVoteDuration,
        uint256 maximumVoteDuration
    ) external returns (CommunityClassVoterPool) {
        CommunityClass _class = new CommunityClassVoterPool();
        ERC1967Proxy _proxy = new WeightedCommunityClassProxy(
            address(_class),
            weight,
            minimumProjectQuorum,
            minimumVoteDelay,
            maximumVoteDelay,
            minimumVoteDuration,
            maximumVoteDuration
        );
        CommunityClassVoterPool _proxyClass = CommunityClassVoterPool(address(_proxy));
        _proxyClass.transferOwnership(msg.sender);
        return _proxyClass;
    }
}

/**
 * @title Project Class Factory
 * @notice small factory intended to reduce construction size for project community classes
 */
contract ProjectClassFactory {
    /// @notice create a new community class representing an ERC-721 token based community
    /// @param projectToken the token underlier for the community
    /// @param weight the weight of a single voting share
    /// @param minimumProjectQuorum the least possible quorum for any vote
    /// @param minimumVoteDelay the least possible vote delay
    /// @param maximumVoteDelay the least possible vote delay
    /// @param minimumVoteDuration the least possible voting duration
    /// @param maximumVoteDuration the least possible voting duration
    function createErc721(
        address projectToken,
        uint256 weight,
        uint256 minimumProjectQuorum,
        uint256 minimumVoteDelay,
        uint256 maximumVoteDelay,
        uint256 minimumVoteDuration,
        uint256 maximumVoteDuration
    ) external returns (ProjectCommunityClass) {
        CommunityClass _class = new CommunityClassERC721();
        ERC1967Proxy _proxy = new ProjectCommunityClassProxy(
            address(_class),
            projectToken,
            weight,
            minimumProjectQuorum,
            minimumVoteDelay,
            maximumVoteDelay,
            minimumVoteDuration,
            maximumVoteDuration
        );
        CommunityClassERC721 _proxyClass = CommunityClassERC721(address(_proxy));
        _proxyClass.transferOwnership(msg.sender);
        return _proxyClass;
    }

    /// @notice create a new community class representing a closed ERC-721 token based community
    /// @param projectToken the token underlier for the community
    /// @param tokenThreshold the number of tokens required to propose a vote
    /// @param weight the weight of a single voting share
    /// @param minimumProjectQuorum the least possible quorum for any vote
    /// @param minimumVoteDelay the least possible vote delay
    /// @param maximumVoteDelay the least possible vote delay
    /// @param minimumVoteDuration the least possible voting duration
    /// @param maximumVoteDuration the least possible voting duration
    function createClosedErc721(
        address projectToken,
        uint256 tokenThreshold,
        uint256 weight,
        uint256 minimumProjectQuorum,
        uint256 minimumVoteDelay,
        uint256 maximumVoteDelay,
        uint256 minimumVoteDuration,
        uint256 maximumVoteDuration
    ) external returns (ProjectCommunityClass) {
        CommunityClass _class = new CommunityClassClosedERC721();
        ERC1967Proxy _proxy = new ClosedProjectCommunityClassProxy(
            address(_class),
            projectToken,
            tokenThreshold,
            weight,
            minimumProjectQuorum,
            minimumVoteDelay,
            maximumVoteDelay,
            minimumVoteDuration,
            maximumVoteDuration
        );
        CommunityClassClosedERC721 _proxyClass = CommunityClassClosedERC721(address(_proxy));
        _proxyClass.transferOwnership(msg.sender);
        return _proxyClass;
    }
}
