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

import { OwnableInitializable } from "../contracts/access/OwnableInitializable.sol";

import { ProposalBuilder } from "../contracts/ProposalBuilder.sol";
import { ProposalBuilderProxy } from "../contracts/ProposalBuilderProxy.sol";

/**
 * @notice deploy factories and contract for GovernanceBuilder
 */
contract DeployProposalBuilder is Script {
    event ProposalBuilderDeployed(address builderAddress);
    event ProposalBuilderUpgraded(address builderAddress);

    /**
     * @notice deploy the Collective ProposalBuilder
     */
    function deploy() external {
        vm.startBroadcast();
        address _governance = vm.envAddress("GOVERNANCE_ADDRESS");
        address _storage = vm.envAddress("STORAGE_ADDRESS");
        address _meta = vm.envAddress("META_ADDRESS");
        ProposalBuilder _builder = new ProposalBuilder();
        ProposalBuilderProxy _proxy = new ProposalBuilderProxy(address(_builder), _governance, _storage, _meta);
        emit ProposalBuilderDeployed(address(_proxy));

        OwnableInitializable _ownable = OwnableInitializable(_meta);
        _ownable.transferOwnership(address(_proxy));
        vm.stopBroadcast();
    }

    /**
     * @notice deploy the Collective ProposalBuilder
     */
    function upgrade() external {
        address _builderAddr = vm.envAddress("BUILDER_ADDRESS");
        address _governance = vm.envAddress("GOVERNANCE_ADDRESS");
        address _storage = vm.envAddress("STORAGE_ADDRESS");
        address _meta = vm.envAddress("META_ADDRESS");
        address payable _proxy = payable(_builderAddr);
        vm.startBroadcast();
        ProposalBuilder _builder = new ProposalBuilder();
        ProposalBuilderProxy _pbuilder = ProposalBuilderProxy(_proxy);
        _pbuilder.upgrade(address(_builder), _governance, _storage, _meta, uint8(_builder.version()));
        emit ProposalBuilderUpgraded(address(_proxy));
        vm.stopBroadcast();
    }
}
