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

import "../contracts/VoterClass.sol";

/// @title Governance Builder interface
/// @notice Requirements for Governance Builder implementation
/// @custom:type interface
interface Builder {
    event GovernanceContractCreated(address creator, address governance);
    event BuilderContractInitialized(address creator);
    event BuilderSupervisorAdded(address creator, address supervisor);
    event BuilderVoterClassAdded(address creator, string name, uint32 version);

    struct GovernanceProperties {
        address[] _supervisorList;
        VoterClass _class;
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure returns (string memory);

    /// @notice return the version of this implementation
    /// @return uint32 version number
    function version() external pure returns (uint32);

    /// @notice initialize and create a new builder context for this sender
    /// @return Builder this contract
    function aGovernance() external returns (Builder);

    /// @notice add a supervisor to the supervisor list for the next constructed contract contract
    /// @dev maintains an internal list which increases with every call
    /// @param _supervisor the address of the wallet representing a supervisor for the project
    /// @return Builder this contract
    function withSupervisor(address _supervisor) external returns (Builder);

    /// @notice set the VoterClass to be used for the next constructed contract
    /// @param _classAddress the address of the VoterClass contract
    /// @return Builder this contract
    function withVoterClassAddress(address _classAddress) external returns (Builder);

    /// @notice set the VoterClass to be used for the next constructed contract
    /// @dev the type safe VoterClass for use within Solidity code
    /// @param _class the address of the VoterClass contract
    /// @return Builder this contract
    function withVoterClass(VoterClass _class) external returns (Builder);

    /// @notice build the specified contract
    /// @dev contructs a new contract and may require a large gas fee, does not reinitialize context
    /// @return the address of the new Governance contract
    function build() external returns (address);
}
