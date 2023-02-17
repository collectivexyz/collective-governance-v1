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

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../../contracts/Constant.sol";
import "../../contracts/access/ConfigurableMutable.sol";
import "../../contracts/access/VersionedContract.sol";
import "../../contracts/community/CommunityClass.sol";
import "../../contracts/access/OwnableInitializable.sol";

/// @title ScheduledCommunityClass
/// @notice defines the configurable parameters for a community
abstract contract ScheduledCommunityClass is
    WeightedCommunityClass,
    VersionedContract,
    OwnableInitializable,
    UUPSUpgradeable,
    Initializable,
    ERC165
{
    event UpgradeAuthorized(address sender, address owner);
    event Initialized(
        uint256 voteWeight,
        uint256 minimumQuorum,
        uint256 minimumDelay,
        uint256 maximumDelay,
        uint256 minimumDuration,
        uint256 maximumDuration
    );
    event Upgraded(
        uint256 voteWeight,
        uint256 minimumQuorum,
        uint256 minimumDelay,
        uint256 maximumDelay,
        uint256 minimumDuration,
        uint256 maximumDuration
    );

    /// @notice weight of a single voting share
    uint256 private _weight;

    /// @notice minimum vote delay for any vote
    uint256 private _minimumVoteDelay;

    /// @notice maximum vote delay for any vote
    uint256 private _maximumVoteDelay;

    /// @notice minimum time for any vote
    uint256 private _minimumVoteDuration;

    /// @notice maximum time for any vote
    uint256 private _maximumVoteDuration;

    /// @notice minimum quorum for any vote
    uint256 private _minimumProjectQuorum;

    /// @notice create a new community class representing community preferences
    /// @param _voteWeight the weight of a single voting share
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    function initialize(
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration
    )
        public
        virtual
        initializer
        requireValidWeight(_voteWeight)
        requireProjectQuorum(_minimumQuorum)
        requireMinimumDelay(_minimumDelay)
        requireMaximumDelay(_maximumDelay)
        requireMinimumDuration(_minimumDuration)
    {
        if (_minimumDelay > _maximumDelay) revert MinimumDelayExceedsMaximum(_minimumDelay, _maximumDelay);
        if (_minimumDuration >= _maximumDuration) revert MinimumDurationExceedsMaximum(_minimumDuration, _maximumDuration);
        ownerInitialize(msg.sender);

        _weight = _voteWeight;
        _minimumVoteDelay = _minimumDelay;
        _maximumVoteDelay = _maximumDelay;
        _minimumVoteDuration = _minimumDuration;
        _maximumVoteDuration = _maximumDuration;
        _minimumProjectQuorum = _minimumQuorum;

        emit Initialized(_voteWeight, _minimumQuorum, _minimumDelay, _maximumDelay, _minimumDuration, _maximumDuration);
    }

    /// @notice reset voting parameters for upgrade
    /// @param _voteWeight the weight of a single voting share
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    function upgrade(
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration
    )
        public
        onlyOwner
        requireValidWeight(_voteWeight)
        requireProjectQuorum(_minimumQuorum)
        requireMinimumDelay(_minimumDelay)
        requireMaximumDelay(_maximumDelay)
        requireMinimumDuration(_minimumDuration)
    {
        if (_minimumDelay > _maximumDelay) revert MinimumDelayExceedsMaximum(_minimumDelay, _maximumDelay);
        if (_minimumDuration >= _maximumDuration) revert MinimumDurationExceedsMaximum(_minimumDuration, _maximumDuration);

        _weight = _voteWeight;
        _minimumVoteDelay = _minimumDelay;
        _maximumVoteDelay = _maximumDelay;
        _minimumVoteDuration = _minimumDuration;
        _maximumVoteDuration = _maximumDuration;
        _minimumProjectQuorum = _minimumQuorum;

        emit Upgraded(_voteWeight, _minimumQuorum, _minimumDelay, _maximumDelay, _minimumDuration, _maximumDuration);
    }

    modifier requireValidWeight(uint256 _voteWeight) {
        if (_voteWeight < 1) revert VoteWeightMustBeNonZero();
        _;
    }

    modifier requireProjectQuorum(uint256 _minimumQuorum) {
        if (_minimumQuorum < Constant.MINIMUM_PROJECT_QUORUM)
            revert MinimumQuorumNotPermitted(_minimumQuorum, Constant.MINIMUM_PROJECT_QUORUM);
        _;
    }

    modifier requireMinimumDelay(uint256 _minimumDelay) {
        if (_minimumDelay < Constant.MINIMUM_VOTE_DELAY)
            revert MinimumDelayExceedsMaximum(_minimumDelay, Constant.MINIMUM_VOTE_DELAY);
        _;
    }

    modifier requireMaximumDelay(uint256 _maximumDelay) {
        if (_maximumDelay > Constant.MAXIMUM_VOTE_DELAY)
            revert MaximumDelayNotPermitted(_maximumDelay, Constant.MAXIMUM_VOTE_DELAY);
        _;
    }

    modifier requireMinimumDuration(uint256 _minimumDuration) {
        if (_minimumDuration < Constant.MINIMUM_VOTE_DURATION)
            revert MinimumDurationExceedsMaximum(_minimumDuration, Constant.MINIMUM_VOTE_DURATION);
        _;
    }

    modifier requireMaximumDuration(uint256 _maximumDuration) {
        if (_maximumDuration > Constant.MAXIMUM_VOTE_DURATION)
            revert MaximumDurationNotPermitted(_maximumDuration, Constant.MAXIMUM_VOTE_DURATION);
        _;
    }

    /// @notice return voting weight of each confirmed share
    /// @return uint256 weight applied to one share
    function weight() public view returns (uint256) {
        return _weight;
    }

    /// @notice get the project quorum requirement
    /// @return uint256 the least quorum allowed for any vote
    function minimumProjectQuorum() public view returns (uint256) {
        return _minimumProjectQuorum;
    }

    /// @notice get the project vote delay requirement
    /// @return uint the least vote delay allowed for any vote
    function minimumVoteDelay() public view returns (uint256) {
        return _minimumVoteDelay;
    }

    /// @notice get the project vote delay maximum
    /// @return uint the max vote delay allowed for any vote
    function maximumVoteDelay() public view returns (uint256) {
        return _maximumVoteDelay;
    }

    /// @notice get the vote duration in seconds
    /// @return uint256 the least duration of a vote in seconds
    function minimumVoteDuration() public view returns (uint256) {
        return _minimumVoteDuration;
    }

    /// @notice get the vote duration in seconds
    /// @return uint256 the vote duration of a vote in seconds
    function maximumVoteDuration() public view returns (uint256) {
        return _maximumVoteDuration;
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(Mutable).interfaceId ||
            interfaceId == type(VoterClass).interfaceId ||
            interfaceId == type(CommunityClass).interfaceId ||
            interfaceId == type(WeightedCommunityClass).interfaceId ||
            interfaceId == type(Versioned).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// see UUPSUpgradeable
    function _authorizeUpgrade(address _caller) internal virtual override(UUPSUpgradeable) onlyOwner {
        emit UpgradeAuthorized(_caller, owner());
    }
}
