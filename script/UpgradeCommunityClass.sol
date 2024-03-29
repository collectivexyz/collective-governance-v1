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

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

import { Script } from "forge-std/Script.sol";

import { Versioned } from "../contracts/access/Versioned.sol";
import { CommunityClass, WeightedCommunityClass } from "../contracts/community/CommunityClass.sol";
import { CommunityClassProxy } from "../contracts/community/CommunityClassProxy.sol";

/**
 * @notice Community Class Upgrade Script
 * upgrades a community class proxy returned from the CommunityClassBuilder.  The target
 * may be either from the CommunityClassBuilder or a standalone implementation.
 *
 * @dev supportsInterface(type(CommunityClass).interfaceId) is required to be true
 */
contract UpgradeCommunityClass is Script {
    event UpgradeProxy(
        address proxy,
        address target,
        uint256 weight,
        uint256 minimumProjectQuorum,
        uint256 minimumVoteDelay,
        uint256 maximumVoteDelay,
        uint256 minimumVoteDuration,
        uint256 maximumVoteDuration,
        uint256 gasUsedRebate,
        uint256 baseFeeRebate,
        uint8 version
    );

    error ProxyRequired(address proxyAddress);
    error UUPSProxyRequired(address proxyAddress);
    error CommunityClassRequired(address target);

    function requireCommunityClass(address _target) private view {
        IERC165 _target165 = IERC165(_target);
        if (!_target165.supportsInterface(type(CommunityClass).interfaceId)) revert CommunityClassRequired(_target);
    }

    /**
     * @notice upgrade classproxy to target via environment
     * CLASS_PROXY: community class address
     * TARGET: community class proxy replacement
     */
    function upgrade() external {
        address _classProxy = vm.envAddress("CLASS_PROXY");
        address _target = vm.envAddress("TARGET_PROTOTYPE");
        requireCommunityClass(_target);
        vm.startBroadcast();
        CommunityClassProxy _class = CommunityClassProxy(_target);
        CommunityClassProxy _proxy = CommunityClassProxy(_classProxy);
        address _implementation = _class.getImplementation();
        Versioned _implVersion = Versioned(_implementation);
        WeightedCommunityClass _prototype = WeightedCommunityClass(_target);
        _proxy.upgrade(
            _implementation,
            _prototype.weight(),
            _prototype.minimumProjectQuorum(),
            _prototype.minimumVoteDelay(),
            _prototype.maximumVoteDelay(),
            _prototype.minimumVoteDuration(),
            _prototype.maximumVoteDuration(),
            _prototype.maximumGasUsedRebate(),
            _prototype.maximumBaseFeeRebate(),
            _prototype.communitySupervisorSet(),
            uint8(_implVersion.version())
        );
        emit UpgradeProxy(
            _classProxy,
            _target,
            _prototype.weight(),
            _prototype.minimumProjectQuorum(),
            _prototype.minimumVoteDelay(),
            _prototype.maximumVoteDelay(),
            _prototype.minimumVoteDuration(),
            _prototype.maximumVoteDuration(),
            _prototype.maximumGasUsedRebate(),
            _prototype.maximumBaseFeeRebate(),
            uint8(_implVersion.version())
        );
        vm.stopBroadcast();
    }
}
