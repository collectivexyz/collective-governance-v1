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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "../../contracts/Constant.sol";
import "../../contracts/access/VersionedContract.sol";
import "../../contracts/collection/AddressSet.sol";
import "../../contracts/community/CommunityFactory.sol";

/// @title Community Creator
/// @notice This builder is for creating a community class for use with the Collective
/// Governance contract
contract CommunityBuilder is VersionedContract, ERC165, Ownable {
    string public constant NAME = "community builder";
    uint256 public constant DEFAULT_WEIGHT = 1;

    error CommunityTypeRequired();
    error CommunityTypeChange();
    error ProjectTokenRequired(address tokenAddress);
    error TokenThresholdRequired(uint256 tokenThreshold);
    error NonZeroWeightRequired(uint256 weight);
    error NonZeroQuorumRequired(uint256 quorum);
    error VoterRequired();
    error VoterPoolRequired();

    event CommunityClassInitialized(address sender);
    event CommunityClassType(CommunityType communityType);
    event CommunityVoter(address voter);
    event CommunityClassWeight(uint256 weight);
    event CommunityClassQuorum(uint256 quorum);
    event CommunityClassMinimumVoteDelay(uint256 delay);
    event CommunityClassMaximumVoteDelay(uint256 delay);
    event CommunityClassMinimumVoteDuration(uint256 duration);
    event CommunityClassMaximumVoteDuration(uint256 duration);

    enum CommunityType {
        NONE,
        OPEN,
        POOL,
        ERC721,
        ERC721_CLOSED
    }

    struct CommunityProperties {
        uint256 weight;
        uint256 minimumProjectQuorum;
        uint256 minimumVoteDelay;
        uint256 maximumVoteDelay;
        uint256 minimumVoteDuration;
        uint256 maximumVoteDuration;
        CommunityType communityType;
        address projectToken;
        uint256 tokenThreshold;
        AddressSet addressSet;
    }

    mapping(address => CommunityProperties) private _buildMap;

    WeightedClassFactory private _weightedFactory;

    ProjectClassFactory private _projectFactory;

    constructor() {
        _weightedFactory = new WeightedClassFactory();
        _projectFactory = new ProjectClassFactory();
    }

    modifier requirePool() {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        if (_properties.communityType != CommunityType.POOL) revert VoterPoolRequired();
        _;
    }

    modifier requireNone() {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        if (_properties.communityType != CommunityType.NONE) revert CommunityTypeChange();
        _;
    }

    function aCommunity() external returns (CommunityBuilder) {
        reset();
        emit CommunityClassInitialized(msg.sender);
        return this;
    }

    function asOpenCommunity() external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.OPEN;
        emit CommunityClassType(CommunityType.OPEN);
        return this;
    }

    function asPoolCommunity() external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.POOL;
        _properties.addressSet = Constant.createAddressSet();
        emit CommunityClassType(CommunityType.POOL);
        return this;
    }

    function asErc721Community(address project) external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.ERC721;
        _properties.projectToken = project;
        emit CommunityClassType(CommunityType.ERC721);
        return this;
    }

    function asClosedErc721Community(address project, uint256 tokenThreshold) external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.ERC721_CLOSED;
        _properties.projectToken = project;
        _properties.tokenThreshold = tokenThreshold;
        emit CommunityClassType(CommunityType.ERC721_CLOSED);
        return this;
    }

    function withVoter(address voter) external requirePool returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.addressSet.add(voter);
        emit CommunityVoter(voter);
        return this;
    }

    function withWeight(uint256 _weight) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.weight = _weight;
        emit CommunityClassWeight(_weight);
        return this;
    }

    function withQuorum(uint256 _quorum) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.minimumProjectQuorum = _quorum;
        emit CommunityClassQuorum(_quorum);
        return this;
    }

    function withMinimumVoteDelay(uint256 _delay) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.minimumVoteDelay = _delay;
        emit CommunityClassMinimumVoteDelay(_delay);
        return this;
    }

    function withMaximumVoteDelay(uint256 _delay) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.maximumVoteDelay = _delay;
        emit CommunityClassMaximumVoteDelay(_delay);
        return this;
    }

    function withMinimumVoteDuration(uint256 _duration) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.minimumVoteDuration = _duration;
        emit CommunityClassMinimumVoteDuration(_duration);
        return this;
    }

    function withMaximumVoteDuration(uint256 _duration) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.maximumVoteDuration = _duration;
        emit CommunityClassMaximumVoteDuration(_duration);
        return this;
    }

    function build() public returns (address) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        WeightedCommunityClass _proxy;
        if (_properties.weight < 1) revert NonZeroWeightRequired(_properties.weight);
        if (_properties.minimumProjectQuorum < 1) revert NonZeroQuorumRequired(_properties.minimumProjectQuorum);
        if (_properties.communityType == CommunityType.ERC721_CLOSED) {
            if (_properties.projectToken == address(0x0)) revert ProjectTokenRequired(_properties.projectToken);
            if (_properties.tokenThreshold == 0) revert TokenThresholdRequired(_properties.tokenThreshold);
            _proxy = _projectFactory.createClosedErc721(
                _properties.projectToken,
                _properties.tokenThreshold,
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration
            );
        } else if (_properties.communityType == CommunityType.ERC721) {
            if (_properties.projectToken == address(0x0)) revert ProjectTokenRequired(_properties.projectToken);
            _proxy = _projectFactory.createErc721(
                _properties.projectToken,
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration
            );
        } else if (_properties.communityType == CommunityType.OPEN) {
            _proxy = _weightedFactory.createOpenVote(
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration
            );
        } else if (_properties.communityType == CommunityType.POOL) {
            CommunityClassVoterPool _pool = _weightedFactory.createVoterPool(
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration
            );
            if (_properties.addressSet.size() == 0) revert VoterRequired();
            for (uint256 i = 1; i <= _properties.addressSet.size(); ++i) {
                _pool.addVoter(_properties.addressSet.get(i));
            }
            _pool.makeFinal();
            _proxy = _pool;
        } else {
            revert CommunityTypeRequired();
        }

        return payable(address(_proxy));
    }

    function name() external pure returns (string memory) {
        return NAME;
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(Versioned).interfaceId ||
            interfaceId == type(Ownable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function reset() public {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.weight = DEFAULT_WEIGHT;
        _properties.communityType = CommunityType.NONE;
        _properties.minimumProjectQuorum = 0;
        _properties.minimumVoteDelay = Constant.MINIMUM_VOTE_DELAY;
        _properties.maximumVoteDelay = Constant.MAXIMUM_VOTE_DELAY;
        _properties.minimumVoteDuration = Constant.MINIMUM_VOTE_DURATION;
        _properties.maximumVoteDuration = Constant.MAXIMUM_VOTE_DURATION;
    }
}
