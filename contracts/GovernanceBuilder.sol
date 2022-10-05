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
 * Copyright (c) 2022, collective
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

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "../contracts/Constant.sol";
import "../contracts/GovernanceStorage.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/VoterClass.sol";
import "../contracts/GovernanceCreator.sol";
import "../contracts/StorageFactory.sol";

/// @title Governance GovernanceCreator implementation
/// @notice This builder supports creating new instances of the Collective Governance Contract
contract GovernanceBuilder is GovernanceCreator, ERC165 {
    string public constant NAME = "collective governance builder";

    mapping(address => GovernanceProperties) private _buildMap;

    /// @dev implement the null object pattern requring voter class to be valid
    VoterClass private immutable _voterClassNull;

    StorageCreator private immutable _storageFactory;

    constructor() {
        _voterClassNull = new VoterClassNullObject();
        _storageFactory = new StorageFactory();
    }

    /// @notice initialize and create a new builder context for this sender
    /// @return GovernanceCreator this contract
    function aGovernance() external returns (GovernanceCreator) {
        clear(msg.sender);
        emit GovernanceCreatorContractInitialized(msg.sender);
        return this;
    }

    /// @notice add a supervisor to the supervisor list for the next constructed contract contract
    /// @dev maintains an internal list which increases with every call
    /// @param _supervisor the address of the wallet representing a supervisor for the project
    /// @return GovernanceCreator this contract
    function withSupervisor(address _supervisor) external returns (GovernanceCreator) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.supervisorList.push(_supervisor);
        emit GovernanceCreatorWithSupervisor(msg.sender, _supervisor);
        return this;
    }

    /// @notice set the VoterClass to be used for the next constructed contract
    /// @param _classAddress the address of the VoterClass contract
    /// @return GovernanceCreator this contract
    function withVoterClassAddress(address _classAddress) external returns (GovernanceCreator) {
        IERC165 erc165 = IERC165(_classAddress);
        require(erc165.supportsInterface(type(VoterClass).interfaceId), "VoterClass required");
        return withVoterClass(VoterClass(_classAddress));
    }

    /// @notice set the VoterClass to be used for the next constructed contract
    /// @dev the type safe VoterClass for use within Solidity code
    /// @param _class the address of the VoterClass contract
    /// @return GovernanceCreator this contract
    function withVoterClass(VoterClass _class) public returns (GovernanceCreator) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.class = _class;
        emit GovernanceCreatorWithVoterClass(msg.sender, address(_class), _class.name(), _class.version());
        return this;
    }

    /// @notice set the minimum duration to the specified value
    /// @dev at least one day is required
    /// @param _minimumDuration the duration in seconds
    /// @return GovernanceCreator this contract
    function withMinimumDuration(uint256 _minimumDuration) external returns (GovernanceCreator) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.minimumVoteDuration = _minimumDuration;
        emit GovernanceCreatorWithMinimumDuration(msg.sender, _minimumDuration);
        return this;
    }

    /// @notice build the specified contract
    /// @dev contructs a new contract and may require a large gas fee, does not reinitialize context
    /// @return the address of the new Governance contract
    function build() external returns (address) {
        address _creator = msg.sender;
        GovernanceProperties storage _properties = _buildMap[_creator];
        require(_properties.supervisorList.length > 0, "Supervisor required");
        require(_properties.minimumVoteDuration >= Constant.MINIMUM_VOTE_DURATION, "Longer minimum duration required");
        require(address(_properties.class) != address(_voterClassNull), "Voter class required");
        Storage _storage = _storageFactory.create(_properties.class, _properties.minimumVoteDuration);
        Governance _governance = new CollectiveGovernance(_properties.supervisorList, _properties.class, _storage);
        address _governanceAddress = address(_governance);
        transferOwnership(_storage, _governanceAddress);
        emit GovernanceContractCreated(_creator, _governanceAddress);
        return _governanceAddress;
    }

    /// @notice clear and reset resources associated with sender build requests
    function reset() external {
        // overwrite to truncate data lifetime
        clear(msg.sender);
        delete _buildMap[msg.sender];
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(GovernanceCreator).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    /// @notice return the version of this implementation
    /// @return uint32 version number
    function version() external pure virtual returns (uint32) {
        return Constant.VERSION_1;
    }

    function transferOwnership(Storage _storage, address _targetOwner) private {
        Ownable _ownableStorage = Ownable(address(_storage));
        _ownableStorage.transferOwnership(_targetOwner);
    }

    function clear(address sender) internal {
        GovernanceProperties storage _properties = _buildMap[sender];
        _properties.class = _voterClassNull;
        _properties.supervisorList = new address[](0);
        _properties.minimumVoteDuration = Constant.MINIMUM_VOTE_DURATION;
    }
}
