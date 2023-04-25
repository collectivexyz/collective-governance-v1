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

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { OwnableInitializable } from "../contracts/access/OwnableInitializable.sol";
import { Versioned } from "../contracts/access/Versioned.sol";
import { VersionedContract } from "../contracts/access/VersionedContract.sol";
import { Constant } from "../contracts/Constant.sol";
import { CommunityClass } from "../contracts/community/CommunityClass.sol";
import { Governance } from "../contracts/governance/Governance.sol";
import { Meta, MetaCollection } from "../contracts/collection/MetaSet.sol";
import { Choice, ChoiceCollection } from "../contracts/collection/ChoiceSet.sol";
import { Transaction, TransactionCollection } from "../contracts/collection/TransactionSet.sol";
import { Storage } from "../contracts/storage/Storage.sol";
import { MetaStorage } from "../contracts/storage/MetaStorage.sol";

/**
 * @notice ProposalBuilder is designed to help building up on-chain proposals.  One of the features
 * of the ProposalBuilder, like the other builders in this project is it remembers the previous settings
 * for the build.   This makes it easy and cost effective to create multiple proposals because only
 * changed information needs to be updated on each build cycle.
 */
contract ProposalBuilder is VersionedContract, ERC165, OwnableInitializable, UUPSUpgradeable, Initializable {
    string public constant NAME = "proposal builder";

    error VersionMismatch(uint256 expected, uint256 provided);
    error VersionInvalid(uint256 expected, uint256 provided);
    error NotGovernance(address governance);
    error NotStorage(address _storage);
    error NotMetaStorage(address meta);
    error MetaNotOwned(address meta);
    error StringSizeLimit(address _sender, uint256 len);
    error ProposalNotInitialized(address _sender);

    event UpgradeAuthorized(address sender, address owner);
    event Initialized(address governanceAddress, address storageAddress, address metaAddress);
    event Upgraded(address governanceAddress, address storageAddress, address metaAddress, uint8 version);

    event ProposalInitialized(address _sender);
    event ProposalTransaction(address _sender, address target, uint256 value, uint256 scheduleTime, uint256 transactionId);
    event ProposalDescription(address _sender, string description, string url);
    event ProposalMeta(address _sender, bytes32 name, string value);
    event ProposalQuorum(address _sender, uint256 quorum);
    event ProposalDelay(address _sender, uint256 delay);
    event ProposalDuration(address _sender, uint256 duration);
    event ProposalBuild(address _sender, uint256 proposalId);

    struct ProposalProperties {
        uint256 quorum;
        uint256 voteDelay;
        uint256 voteDuration;
        string description;
        string url;
        TransactionCollection transaction;
        MetaCollection meta;
        ChoiceCollection choice;
    }

    Governance private _governance;
    Storage private _storage;
    MetaStorage private _meta;

    mapping(address => ProposalProperties) private _proposalMap;

    constructor() {
        _disableInitializers();
    }

    /// @notice System factory
    /// @param _governanceAddress address of CollectiveGovernance
    /// @param _storageAddress address of Storage contract
    /// @param _metaAddress address of meta storage
    function initialize(
        address _governanceAddress,
        address _storageAddress,
        address _metaAddress
    )
        public
        initializer
        initializer
        requireGovernance(_governanceAddress)
        requireVersion(_governanceAddress)
        requireStorage(_storageAddress)
        requireMetaStorage(_metaAddress)
    {
        ownerInitialize(msg.sender);
        Governance _gov = Governance(_governanceAddress);
        Storage _stor = Storage(_storageAddress);
        MetaStorage _metaStor = MetaStorage(_metaAddress);
        if (_gov.version() < _stor.version()) revert VersionMismatch(_gov.version(), _stor.version());
        if (_gov.version() < _metaStor.version()) revert VersionMismatch(_gov.version(), _metaStor.version());
        _governance = _gov;
        _storage = _stor;
        _meta = _metaStor;
        emit Initialized(_governanceAddress, _storageAddress, _metaAddress);
    }

    /// @param _governanceAddress address of CollectiveGovernance
    /// @param _storageAddress address of Storage contract
    /// @param _metaAddress address of meta storage
    /// @param _version upgrade version
    function upgrade(
        address _governanceAddress,
        address _storageAddress,
        address _metaAddress,
        uint8 _version
    )
        public
        onlyOwner
        reinitializer(_version)
        requireGovernance(_governanceAddress)
        requireVersion(_governanceAddress)
        requireStorage(_storageAddress)
        requireMetaStorage(_metaAddress)
    {
        Governance _gov = Governance(_governanceAddress);
        Storage _stor = Storage(_storageAddress);
        MetaStorage _metaStor = MetaStorage(_metaAddress);
        if (_gov.version() < _stor.version()) revert VersionMismatch(_gov.version(), _stor.version());
        if (_gov.version() < _metaStor.version()) revert VersionMismatch(_gov.version(), _metaStor.version());
        _governance = _gov;
        _storage = _stor;
        _meta = _metaStor;
        emit Upgraded(_governanceAddress, _storageAddress, _metaAddress, _version);
    }

    modifier requireVersion(address _contract) {
        Versioned _version = Versioned(_contract);
        if (_version.version() < Constant.CURRENT_VERSION) revert VersionInvalid(_version.version(), Constant.CURRENT_VERSION);
        _;
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

    modifier requireMetaOwner() {
        Ownable ownable = Ownable(address(_meta));
        if (ownable.owner() != address(this)) revert MetaNotOwned(address(_meta));
        _;
    }

    modifier requireValidString(string memory _data) {
        uint256 strLen = Constant.len(_data);
        if (strLen > Constant.STRING_DATA_LIMIT) revert StringSizeLimit(msg.sender, strLen);
        _;
    }

    modifier requireAProposal() {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        if (
            address(_properties.transaction) == address(0x0) ||
            address(_properties.meta) == address(0x0) ||
            address(_properties.choice) == address(0x0)
        ) revert ProposalNotInitialized(msg.sender);
        _;
    }

    /**
     * reset the proposal builder for this address
     *
     * @return Builder - this contract
     */
    function aProposal() external returns (ProposalBuilder) {
        clear();
        emit ProposalInitialized(msg.sender);
        return this;
    }

    /// @notice Attach a choice for a choice vote on this proposal
    /// @param _name The name for this choice
    /// @param _description The description of this choice
    /// @param _transactionId The associated transactionId
    function withChoice(
        bytes32 _name,
        string memory _description,
        uint256 _transactionId
    ) external requireAProposal requireValidString(_description) returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.choice.add(Choice(_name, _description, _transactionId, "", 0));
        return this;
    }

    /// @notice Attach a transaction to the proposal.
    /// @param _target the target address for this transaction
    /// @param _value the value to pass to the call
    /// @param _signature the tranaction signature
    /// @param _calldata the call data to pass to the call
    /// @param _scheduleTime the expected call time, within the timelock grace,
    ///        for the transaction
    /// @return ProposalBuilder this builder
    function withTransaction(
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _calldata,
        uint256 _scheduleTime
    ) external requireAProposal returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        Transaction memory transaction = Transaction(_target, _value, _signature, _calldata, _scheduleTime);
        uint256 id = _properties.transaction.add(transaction);
        emit ProposalTransaction(msg.sender, _target, _value, _scheduleTime, id);
        return this;
    }

    /// @notice set the description
    /// @param _description the description
    /// @param _url the url
    /// @return ProposalBuilder this builder
    function withDescription(
        string memory _description,
        string memory _url
    ) external requireAProposal requireValidString(_description) requireValidString(_url) returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.description = _description;
        _properties.url = _url;
        emit ProposalDescription(msg.sender, _description, _url);
        return this;
    }

    /// @notice attach arbitrary metadata to the proposal
    /// @param _name the name of the metadata field
    /// @param _value the value of the metadata
    /// @return ProposalBuilder this builder
    function withMeta(bytes32 _name, string memory _value) external requireAProposal returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.meta.add(Meta(_name, _value));
        emit ProposalMeta(msg.sender, _name, _value);
        return this;
    }

    /// @notice set the minimum quorum
    /// @param _quorum the quorum
    /// @return ProposalBuilder this builder
    function withQuorum(uint256 _quorum) external requireAProposal returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.quorum = _quorum;
        emit ProposalQuorum(msg.sender, _quorum);
        return this;
    }

    /// @notice set the vote delay
    /// @param _delay the delay
    /// @return ProposalBuilder this builder
    function withDelay(uint256 _delay) external requireAProposal returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.voteDelay = _delay;
        emit ProposalDelay(msg.sender, _delay);
        return this;
    }

    /// @notice set the vote duration
    /// @param _duration the duration
    /// @return ProposalBuilder this builder
    function withDuration(uint256 _duration) external requireAProposal returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.voteDuration = _duration;
        emit ProposalDuration(msg.sender, _duration);
        return this;
    }

    /// @notice build the proposal
    /// @return uint256 the propposal id
    function build() external requireAProposal requireMetaOwner returns (uint256) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        uint256 pid = _governance.propose();
        for (uint256 i = 1; i <= _properties.transaction.size(); ++i) {
            Transaction memory transaction = _properties.transaction.get(i);
            _governance.attachTransaction(
                pid,
                transaction.target,
                transaction.value,
                transaction.signature,
                transaction._calldata,
                transaction.scheduleTime
            );
        }
        for (uint256 i = 1; i <= _properties.choice.size(); ++i) {
            Choice memory choice = _properties.choice.get(i);
            _governance.addChoice(pid, choice.name, choice.description, choice.transactionId);
        }
        if (!Constant.empty(_properties.url) || !Constant.empty(_properties.description) || _properties.meta.size() > 0) {
            _meta.describe(pid, _properties.url, _properties.description);
            for (uint256 i = 1; i <= _properties.meta.size(); ++i) {
                Meta memory meta = _properties.meta.get(i);
                _meta.add(pid, meta.name, meta.value);
            }
        }

        _governance.configure(pid, _properties.quorum, _properties.voteDelay, _properties.voteDuration);
        emit ProposalBuild(msg.sender, pid);
        return pid;
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
        CommunityClass _class = _storage.communityClass();
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.quorum = _class.minimumProjectQuorum();
        _properties.voteDelay = _class.minimumVoteDelay();
        _properties.voteDuration = _class.minimumVoteDuration();
        _properties.description = "";
        _properties.url = "";
        _properties.transaction = Constant.createTransactionSet();
        _properties.meta = Constant.createMetaSet();
        _properties.choice = Constant.createChoiceSet();
    }

    /// see UUPSUpgradeable
    function _authorizeUpgrade(address _caller) internal virtual override(UUPSUpgradeable) onlyOwner {
        emit UpgradeAuthorized(_caller, owner());
    }
}
