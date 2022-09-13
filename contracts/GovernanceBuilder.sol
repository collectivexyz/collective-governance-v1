// SPDX-License-Identifier: BSD-3-Clause
/*
 * Copyright 2022 collective.xyz
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
pragma solidity ^0.8.15;

import "../contracts/Governance.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/VoterClass.sol";

interface Builder {
    event GovernanceContractCreated(address _creator, address _governance);
    event BuilderContractInitialized(address _creator);
    event BuilderSupervisorAdded(address _creator, address _supervisor);
    event BuilderVoterClassAdded(address _creator, string _name, uint32 _version);

    struct GovernanceProperties {
        address[] _supervisorList;
        VoterClass _class;
    }

    function withSupervisor(address _supervisor) external returns (Builder);

    function withVoterClass(VoterClass _class) external returns (Builder);

    function build() external returns (address);
}

contract GovernanceBuilder is Builder {
    mapping(address => GovernanceProperties) private _buildMap;

    // solium-disable-next-line no-empty-blocks
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

    function withVoterClass(VoterClass _class) external returns (Builder) {
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
}
