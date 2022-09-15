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

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "../contracts/Governance.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/VoterClass.sol";
import "../contracts/Builder.sol";

contract GovernanceBuilder is Builder {
    string public constant NAME = "collective.xyz governance contract builder";
    uint32 public constant VERSION_1 = 1;

    mapping(address => GovernanceProperties) private _buildMap;

    // solhint-disable-next-line no-empty-blocks
    constructor() {}

    function aGovernance() external returns (GovernanceBuilder) {
        delete _buildMap[msg.sender];
        emit BuilderContractInitialized(msg.sender);
        return this;
    }

    function withSupervisor(address _supervisor) external returns (Builder) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties._supervisorList.push(_supervisor);
        emit BuilderSupervisorAdded(msg.sender, _supervisor);
        return this;
    }

    function withVoterClassAddress(address _classAddress) external returns (Builder) {
        IERC165 erc165 = IERC165(_classAddress);
        require(erc165.supportsInterface(type(VoterClass).interfaceId), "VoterClass required");
        return withVoterClass(VoterClass(_classAddress));
    }

    function withVoterClass(VoterClass _class) public returns (Builder) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties._class = _class;
        emit BuilderVoterClassAdded(msg.sender, _class.name(), _class.version());
        return this;
    }

    function withVoterClassErc721(address _erc721Address) public returns (Builder) {
        VoterClass _class = new VoterClassERC721(_erc721Address, 1);
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties._class = _class;
        emit BuilderVoterClassAdded(msg.sender, _class.name(), _class.version());
        return this;
    }


    function build() external returns (address) {
        address _creator = msg.sender;
        GovernanceProperties storage _properties = _buildMap[_creator];
        require(_properties._supervisorList.length > 0, "Supervisor is required");
        require(address(_properties._class) != address(0x0), "Voter class is required");
        Governance _governance = new CollectiveGovernance(_properties._supervisorList, _properties._class);
        address _governanceAddress = address(_governance);
        emit GovernanceContractCreated(_creator, _governanceAddress);
        return _governanceAddress;
    }

    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    function version() external pure virtual returns (uint32) {
        return VERSION_1;
    }
}
