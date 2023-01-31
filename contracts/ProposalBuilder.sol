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

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../contracts/access/VersionedContract.sol";
import "../contracts/Governance.sol";
import "../contracts/storage/Storage.sol";
import "../contracts/storage/MetaStorage.sol";

contract ProposalBuilder is VersionedContract, ERC165, Ownable {
    string public constant NAME = "proposal builder";

    error VersionMismatch(uint256 expected, uint256 provided);
    error VersionInvalid(uint256 expected, uint256 provided);
    error NotGovernance(address _address);
    error NotStorage(address _address);
    error NotMetaStorage(address _address);

    event ProposalInitialized(address _sender);

    struct ProposalProperties {
        uint256 quorum;
        uint256 voteDelay;
        uint256 voteDuration;
        string description;
        string url;
    }

    Governance private _governance;
    Storage private _storage;
    MetaStorage private _meta;

    mapping(address => ProposalProperties) private _proposalMap;

    /// @notice System factory
    /// @param _governanceAddress address of CollectiveGovernance
    /// @param _storageAddress address of Storage contract
    /// @param _metaAddress address of meta storage
    constructor(
        address _governanceAddress,
        address _storageAddress,
        address _metaAddress
    ) requireGovernance(_governanceAddress) requireStorage(_storageAddress) requireMetaStorage(_metaAddress) {
        Governance _gov = Governance(_governanceAddress);
        Storage _stor = Storage(_storageAddress);
        MetaStorage _metaStor = MetaStorage(_metaAddress);
        if (_gov.version() > _stor.version()) revert VersionMismatch(_gov.version(), _stor.version());
        if (_gov.version() > _metaStor.version()) revert VersionMismatch(_gov.version(), _metaStor.version());
        if (_gov.version() < Constant.VERSION_3) revert VersionInvalid(_gov.version(), Constant.VERSION_3);
        _governance = _gov;
        _storage = _stor;
        _meta = _metaStor;
    }

    modifier requireGovernance(address _governanceAddress) {
        Governance _gov = Governance(_governanceAddress);
        if (!_gov.supportsInterface(type(Governance).interfaceId)) revert NotGovernance(_governanceAddress);
        _;
    }

    modifier requireStorage(address _storageAddress) {
        Storage _store = Storage(_storageAddress);
        if (!_store.supportsInterface(type(Storage).interfaceId)) revert NotStorage(_storageAddress);
        _;
    }

    modifier requireMetaStorage(address _metaAddress) {
        MetaStorage _metaStorage = MetaStorage(_metaAddress);
        if (!_metaStorage.supportsInterface(type(MetaStorage).interfaceId)) revert NotMetaStorage(_metaAddress);
        _;
    }

    function aProposal() external returns (ProposalBuilder) {
        clear();
        emit ProposalInitialized(msg.sender);
        return this;
    }

    // @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(Ownable).interfaceId ||
            interfaceId == type(Versioned).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function clear() public {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
    }
}
