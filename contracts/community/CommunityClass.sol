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

import { VoterClass } from "../community/VoterClass.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";

/// @title CommunityClass interface
/// @notice defines the configurable parameters for a community
/// @custom:type interface
interface CommunityClass is VoterClass {
    // setup errors
    error SupervisorListEmpty();
    error GasUsedRebateMustBeLarger(uint256 gasUsedRebate, uint256 minimumRebate);
    error BaseFeeRebateMustBeLarger(uint256 baseFee, uint256 minimumBaseFee);
    error VoteWeightMustBeNonZero();
    error MinimumDelayExceedsMaximum(uint256 delay, uint256 minimumDelay);
    error MaximumDelayNotPermitted(uint256 delay, uint256 maximumDelay);
    error MinimumDurationExceedsMaximum(uint256 duration, uint256 minimumDuration);
    error MinimumDurationNotPermitted(uint256 duration, uint256 minimumDuration);
    error MaximumDurationExceedsMaximum(uint256 duration, uint256 maximumDuration);
    error MaximumDurationNotPermitted(uint256 duration, uint256 maximumDuration);
    error MinimumQuorumNotPermitted(uint256 quorum, uint256 minimumProjectQuorum);

    /// @notice get the project vote delay requirement
    /// @return uint256 the least vote delay allowed for any vote
    function minimumVoteDelay() external view returns (uint256);

    /// @notice get the project vote delay maximum
    /// @return uint256 the max vote delay allowed for any vote
    function maximumVoteDelay() external view returns (uint256);

    /// @notice get the vote duration minimum in seconds
    /// @return uint256 the least duration of a vote in seconds
    function minimumVoteDuration() external view returns (uint256);

    /// @notice get the vote duration maximum in seconds
    /// @return uint256 the vote duration of a vote in seconds
    function maximumVoteDuration() external view returns (uint256);

    /// @notice get the project quorum requirement
    /// @return uint256 the least quorum allowed for any vote
    function minimumProjectQuorum() external view returns (uint256);

    /// @notice maximum gas used rebate
    /// @return uint256 the maximum rebate
    function maximumGasUsedRebate() external view returns (uint256);

    /// @notice maximum base fee rebate
    /// @return uint256 the base fee rebate
    function maximumBaseFeeRebate() external view returns (uint256);

    /// @notice return the community supervisors
    /// @return AddressSet the supervisor set
    function communitySupervisorSet() external view returns (AddressCollection);

    /// @notice determine if adding a proposal is approved for this voter
    /// @param _sender The address of the sender
    /// @return bool true if this address is approved
    function canPropose(address _sender) external view returns (bool);
}

interface WeightedCommunityClass is CommunityClass {
    /// @notice create a new community class representing community preferences
    /// @param _voteWeight the weight of a vote
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    /// @param _gasUsedRebate The maximum rebate for gas used
    /// @param _baseFeeRebate The maximum base fee rebate
    /// @param _supervisorList the list of supervisors for this project
    function initialize(
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate,
        AddressCollection _supervisorList
    ) external;

    /// @notice reset voting parameters for upgrade
    /// @param _voteWeight the weight of a vote
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    /// @param _gasUsedRebate The maximum rebate for gas used
    /// @param _baseFeeRebate The maximum base fee rebate
    /// @param _supervisorList the list of supervisors for this project
    /// @param version upgrade version
    function upgrade(
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate,
        AddressCollection _supervisorList,
        uint8 version
    ) external;

    /// @notice return voting weight of each confirmed share
    /// @return uint256 weight applied to one share
    function weight() external view returns (uint256);
}

interface ProjectCommunityClass is WeightedCommunityClass {
    /// @notice create a new community class representing community preferences
    /// @param _contract the token project contract address
    /// @param _voteWeight the weight of a vote
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    /// @param _gasUsedRebate The maximum rebate for gas used
    /// @param _baseFeeRebate The maximum base fee rebate
    /// @param _supervisorList the list of supervisors for this project
    function initialize(
        address _contract,
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate,
        AddressCollection _supervisorList
    ) external;
}
