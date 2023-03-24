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
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Upgrade } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

import { Script } from "forge-std/Script.sol";

import { CommunityClass } from "../contracts/community/CommunityClass.sol";
import { CommunityClassProxy } from "../contracts/community/CommunityClassProxy.sol";

/**
 * @notice Community Class Upgrade Script
 * upgrades a community class proxy returned from the CommunityClassBuilder.  The target
 * may be either from the CommunityClassBuilder or a standalone implementation.
 *
 * @dev supportsInterface(type(CommunityClass).interfaceId) is required to be true
 */
contract UpgradeCommunityClass is Script {
    event UpgradeProxy(address proxy, address target);

    error ProxyRequired(address proxyAddress);
    error UUPSProxyRequired(address proxyAddress);
    error CommunityClassRequired(address target);

    modifier requireProxy(address classProxy) {
        IERC165 _erc165 = IERC165(classProxy);
        if (!_erc165.supportsInterface(type(CommunityClassProxy).interfaceId)) revert ProxyRequired(classProxy);
        if (!_erc165.supportsInterface(type(UUPSUpgradeable).interfaceId)) revert UUPSProxyRequired(classProxy);
        _;
    }

    /**
     * @notice perform an upgrade of classProxy to target implementation
     * @param classProxy the classProxy returned by CommunityClassBuilder
     * @param target the target implementation for the upgrade
     */
    function upgrade(address payable classProxy, address target) external requireProxy(classProxy) {
        UUPSUpgradeable __uups = UUPSUpgradeable(classProxy);
        IERC165 _target165 = IERC165(target);
        if (!_target165.supportsInterface(type(CommunityClass).interfaceId)) revert CommunityClassRequired(target);
        __uups.upgradeTo(target);
        emit UpgradeProxy(classProxy, target);
    }
}
