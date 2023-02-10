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

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../contracts/access/VersionedContract.sol";
import "../contracts/Constant.sol";
import "../contracts/Governance.sol";
import "../contracts/collection/MetaSet.sol";
import "../contracts/collection/ChoiceSet.sol";
import "../contracts/collection/TransactionSet.sol";
import "../contracts/storage/Storage.sol";
import "../contracts/storage/MetaStorage.sol";

contract ProposalBuilder is VersionedContract, ERC165, Ownable {
    string public constant NAME = "proposal builder";

    error VersionMismatch(uint256 expected, uint256 provided);
    error VersionInvalid(uint256 expected, uint256 provided);
    error NotGovernance(address _address);
    error NotStorage(address _address);
    error NotMetaStorage(address _address);
    error StringSizeLimit(address _sender, uint256 len);

    event ProposalInitialized(address _sender);
    event ProposalTransaction(address _sender, address target, uint256 value, uint256 scheduleTime, uint256 transactionId);
    event ProposalDescription(address _sender, string description, string url);

    struct ProposalProperties {
        uint256 quorum;
        uint256 voteDelay;
        uint256 voteDuration;
        string description;
        string url;
        TransactionSet transaction;
        MetaSet meta;
        ChoiceSet choice;
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
    )
        requireGovernance(_governanceAddress)
        requireVersion(_governanceAddress)
        requireStorage(_storageAddress)
        requireMetaStorage(_metaAddress)
    {
        Governance _gov = Governance(_governanceAddress);
        Storage _stor = Storage(_storageAddress);
        MetaStorage _metaStor = MetaStorage(_metaAddress);
        if (_gov.version() > _stor.version()) revert VersionMismatch(_gov.version(), _stor.version());
        if (_gov.version() > _metaStor.version()) revert VersionMismatch(_gov.version(), _metaStor.version());
        _governance = _gov;
        _storage = _stor;
        _meta = _metaStor;
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

    modifier requireValidString(string memory _data) {
        uint256 strLen = Constant.len(_data);
        if (strLen > Constant.STRING_DATA_LIMIT) revert StringSizeLimit(msg.sender, strLen);
        _;
    }

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
    ) external requireValidString(_description) returns (ProposalBuilder) {
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
    ) external returns (ProposalBuilder) {
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
    ) external requireValidString(_description) requireValidString(_url) returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.description = _description;
        _properties.url = _url;
        return this;
    }

    /// @notice attach arbitrary metadata to the proposal
    /// @param _name the name of the metadata field
    /// @param _value the value of the metadata
    /// @return ProposalBuilder this builder
    function withMeta(bytes32 _name, string memory _value) external returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.meta.add(Meta(_name, _value));
        return this;
    }

    /// @notice set the minimum quorum
    /// @param _quorum the quorum
    /// @return ProposalBuilder this builder
    function withQuorum(uint256 _quorum) external returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.quorum = _quorum;
        return this;
    }

    /// @notice set the vote delay
    /// @param _delay the delay
    /// @return ProposalBuilder this builder
    function withDelay(uint256 _delay) external returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.voteDelay = _delay;
        return this;
    }

    /// @notice set the vote duration
    /// @param _duration the duration
    /// @return ProposalBuilder this builder
    function withDuration(uint256 _duration) external returns (ProposalBuilder) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.voteDuration = _duration;
        return this;
    }

    /// @notice build the proposal
    /// @return uint256 the propposal id
    function build() external returns (uint256) {
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        uint256 pid = _governance.propose();
        if (_properties.transaction.size() > 0) {
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
        }
        if (_properties.choice.size() > 0) {
            for (uint256 i = 1; i <= _properties.choice.size(); ++i) {
                Choice memory choice = _properties.choice.get(i);
                _governance.addChoice(pid, choice.name, choice.description, choice.transactionId);
            }
        }
        if (!Constant.empty(_properties.url) || !Constant.empty(_properties.description) || _properties.meta.size() > 0) {
            _meta.describe(pid, _properties.url, _properties.description);
            for (uint256 i = 1; i <= _properties.meta.size(); ++i) {
                Meta memory meta = _properties.meta.get(i);
                _meta.addMeta(pid, meta.name, meta.value);
            }
        }

        _governance.configure(pid, _properties.quorum, _properties.voteDelay, _properties.voteDuration);
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
        ProposalProperties storage _properties = _proposalMap[msg.sender];
        _properties.quorum = 0;
        _properties.voteDelay = 0;
        _properties.voteDuration = 0;
        _properties.description = "";
        _properties.url = "";
        _properties.transaction = new TransactionSet();
        _properties.meta = Constant.createMetaSet();
        _properties.choice = Constant.createChoiceSet();
    }
}
