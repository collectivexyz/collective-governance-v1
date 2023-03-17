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

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { CommunityClass, WeightedCommunityClass, ProjectCommunityClass } from "../../contracts/community/CommunityClass.sol";
import { CommunityClassClosedERC721 } from "../../contracts/community/CommunityClassClosedERC721.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";

contract WeightedCommunityClassProxy is ERC1967Proxy {
    /// @notice create a new community class proxy
    /// @param _implementation the address of the community class implementation
    /// @param _voteWeight the weight of a single voting share
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    /// @param _gasUsedRebate The maximum rebate for gas used
    /// @param _baseFeeRebate The maximum base fee rebate
    /// @param _supervisorList the list of supervisors for this project
    constructor(
        address _implementation,
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate,
        AddressCollection _supervisorList
    )
        ERC1967Proxy(
            _implementation,
            abi.encodeWithSelector(
                WeightedCommunityClass.initialize.selector,
                _voteWeight,
                _minimumQuorum,
                _minimumDelay,
                _maximumDelay,
                _minimumDuration,
                _maximumDuration,
                _gasUsedRebate,
                _baseFeeRebate,
                _supervisorList
            )
        )
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function upgrade(
        address _implementation,
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate,
        AddressCollection _supervisorList
    ) external {
        _upgradeToAndCallUUPS(
            _implementation,
            abi.encodeWithSelector(
                WeightedCommunityClass.upgrade.selector,
                _voteWeight,
                _minimumQuorum,
                _minimumDelay,
                _maximumDelay,
                _minimumDuration,
                _maximumDuration,
                _gasUsedRebate,
                _baseFeeRebate,
                _supervisorList
            ),
            false
        );
    }
}

contract ProjectCommunityClassProxy is ERC1967Proxy {
    /// @notice create a new community class proxy
    /// @param _implementation the address of the community class implementation
    /// @param _contract Address of the token contract
    /// @param _voteWeight the weight of a single voting share
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    /// @param _gasUsedRebate The maximum rebate for gas used
    /// @param _baseFeeRebate The maximum base fee rebate
    /// @param _supervisorList the list of supervisors for this project
    constructor(
        address _implementation,
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
    )
        ERC1967Proxy(
            _implementation,
            abi.encodeWithSelector(
                ProjectCommunityClass.initialize.selector,
                _contract,
                _voteWeight,
                _minimumQuorum,
                _minimumDelay,
                _maximumDelay,
                _minimumDuration,
                _maximumDuration,
                _gasUsedRebate,
                _baseFeeRebate,
                _supervisorList
            )
        )
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function upgrade(
        address _implementation,
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate,
        AddressCollection _supervisorList
    ) external {
        _upgradeToAndCallUUPS(
            _implementation,
            abi.encodeWithSelector(
                WeightedCommunityClass.upgrade.selector,
                _voteWeight,
                _minimumQuorum,
                _minimumDelay,
                _maximumDelay,
                _minimumDuration,
                _maximumDuration,
                _gasUsedRebate,
                _baseFeeRebate,
                _supervisorList
            ),
            false
        );
    }
}

contract ClosedProjectCommunityClassProxy is ERC1967Proxy {
    /// @notice create a new community class proxy
    /// @param _implementation the address of the community class implementation
    /// @param _contract Address of the token contract
    /// @param _voteWeight the weight of a single voting share
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    /// @param _gasUsedRebate The maximum rebate for gas used
    /// @param _baseFeeRebate The maximum base fee rebate
    /// @param _supervisorList the list of supervisors for this project
    constructor(
        address _implementation,
        address _contract,
        uint256 _tokenThreshold,
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate,
        AddressCollection _supervisorList
    )
        ERC1967Proxy(
            _implementation,
            abi.encodeWithSelector(
                CommunityClassClosedERC721.initialize.selector,
                _contract,
                _tokenThreshold,
                _voteWeight,
                _minimumQuorum,
                _minimumDelay,
                _maximumDelay,
                _minimumDuration,
                _maximumDuration,
                _gasUsedRebate,
                _baseFeeRebate,
                _supervisorList
            )
        )
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function upgrade(
        address _implementation,
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration,
        uint256 _gasUsedRebate,
        uint256 _baseFeeRebate,
        AddressCollection _supervisorList
    ) external {
        _upgradeToAndCallUUPS(
            _implementation,
            abi.encodeWithSelector(
                WeightedCommunityClass.upgrade.selector,
                _voteWeight,
                _minimumQuorum,
                _minimumDelay,
                _maximumDelay,
                _minimumDuration,
                _maximumDuration,
                _gasUsedRebate,
                _baseFeeRebate,
                _supervisorList
            ),
            false
        );
    }
}
