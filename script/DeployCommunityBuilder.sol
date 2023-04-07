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

import { Script } from "forge-std/Script.sol";

import { WeightedClassFactory, ProjectClassFactory } from "../contracts/community/CommunityFactory.sol";
import { CommunityBuilder } from "../contracts/community/CommunityBuilder.sol";
import { CommunityBuilderProxy } from "../contracts/community/CommunityBuilderProxy.sol";

/**
 * @notice deploy factories and contract for GovernanceBuilder
 */
contract DeployCommunityBuilder is Script {
    event CommunityBuilderDeployed(address communityAddress);
    event CommunityBuilderUpgraded(address communityAddress);

    /**
     * @notice deploy the Collective CommunityBuilder
     */
    function deploy() external {
        vm.startBroadcast();
        WeightedClassFactory _weightedFactory = new WeightedClassFactory();
        ProjectClassFactory _projectFactory = new ProjectClassFactory();

        CommunityBuilder _builder = new CommunityBuilder();
        CommunityBuilderProxy _proxy = new CommunityBuilderProxy(
            address(_builder),
            address(_weightedFactory),
            address(_projectFactory)
        );
        emit CommunityBuilderDeployed(address(_proxy));
        vm.stopBroadcast();
    }

    /**
     * @notice deploy the Collective CommunityBuilder
     */
    function upgrade() external {
        address _builderAddr = vm.envAddress("BUILDER_ADDRESS");
        address payable _proxy = payable(_builderAddr);
        vm.startBroadcast();
        WeightedClassFactory _weightedFactory = new WeightedClassFactory();
        ProjectClassFactory _projectFactory = new ProjectClassFactory();

        CommunityBuilder _builder = new CommunityBuilder();
        CommunityBuilderProxy _pbuilder = CommunityBuilderProxy(_proxy);
        _pbuilder.upgrade(address(_builder), address(_weightedFactory), address(_projectFactory));
        emit CommunityBuilderUpgraded(address(_proxy));
        vm.stopBroadcast();
    }
}
