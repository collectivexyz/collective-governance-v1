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

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Governance } from "../../contracts/governance/Governance.sol";
import { GovernanceFactory } from "../../contracts/governance/GovernanceFactory.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { Storage } from "../../contracts/storage/Storage.sol";
import { StorageFactory } from "../../contracts/storage/StorageFactory.sol";
import { MetaStorage } from "../../contracts/storage/MetaStorage.sol";
import { MetaStorageFactory } from "../../contracts/storage/MetaStorageFactory.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { VersionedContract } from "../../contracts/access/VersionedContract.sol";
import { TimeLock } from "../../contracts/treasury/TimeLock.sol";
import { TimeLocker } from "../../contracts/treasury/TimeLocker.sol";
import { OwnableInitializable } from "../../contracts/access/OwnableInitializable.sol";

/// @title Collective Governance creator
/// @notice This builder supports creating new instances of the Collective Governance contract
contract GovernanceBuilder is VersionedContract, ERC165, OwnableInitializable, UUPSUpgradeable, Initializable {
    string public constant NAME = "governance builder";

    error MetaStorageFactoryRequired(address meta);
    error StorageVersionMismatch(address _storage, uint32 expected, uint32 provided);
    error MetaVersionMismatch(address meta, uint32 expected, uint32 provided);
    error CommunityClassRequired(address voterClass);

    event UpgradeAuthorized(address sender, address owner);
    event Initialized(address metaStorageFactory, address storageFactory, address governanceFactory);
    event Upgraded(address metaStorageFactory, address storageFactory, address governanceFactory, uint8 version);

    /// @notice new contract created
    event GovernanceContractCreated(
        address creator,
        bytes32 name,
        address _storage,
        address metaStorage,
        address timeLock,
        address governance
    );
    /// @notice initialized local state for sender
    event GovernanceContractInitialized(address creator);
    /// @notice add supervisor
    event GovernanceContractWithSupervisor(address creator, address supervisor);
    /// @notice set voterclass
    event GovernanceContractWithCommunityClass(address creator, address class, string name, uint32 version);
    /// @notice set minimum delay
    event GovernanceContractWithMinimumVoteDelay(address creator, uint256 delay);
    /// @notice set maximum delay
    event GovernanceContractWithMaximumVoteDelay(address creator, uint256 delay);
    /// @notice set minimum duration
    event GovernanceContractWithMinimumDuration(address creator, uint256 duration);
    /// @notice set maximum duration
    event GovernanceContractWithMaximumDuration(address creator, uint256 duration);
    /// @notice set minimum quorum
    event GovernanceContractWithMinimumQuorum(address creator, uint256 quorum);
    /// @notice add name
    event GovernanceContractWithName(address creator, bytes32 name);
    /// @notice add url
    event GovernanceContractWithUrl(address creator, string url);
    /// @notice add description
    event GovernanceContractWithDescription(address creator, string description);

    /// @notice The timelock created
    event TimeLockCreated(address timeLock, uint256 lockTime);

    /// @notice settings state used by builder for creating Governance contract
    struct GovernanceProperties {
        /// @notice community name
        bytes32 name;
        /// @notice community url
        string url;
        /// @notice community description
        string description;
        /// @notice voting class
        CommunityClass class;
    }

    mapping(address => GovernanceProperties) private _buildMap;

    StorageFactory public _storageFactory;
    MetaStorageFactory public _metaStorageFactory;
    GovernanceFactory public _governanceFactory;

    mapping(address => bool) public _governanceContractRegistered;

    constructor() {
        _disableInitializers();
    }

    /**
     * @param _govFactory the governance factory address
     * @param _sFactory the storage factory address
     * @param _mStorageFactory the meta storage factory address
     */
    function initialize(address _govFactory, address _sFactory, address _mStorageFactory) public initializer {
        ownerInitialize(msg.sender);
        _storageFactory = StorageFactory(_sFactory);
        _metaStorageFactory = MetaStorageFactory(_mStorageFactory);
        _governanceFactory = GovernanceFactory(_govFactory);
        emit Initialized(address(_storageFactory), address(_metaStorageFactory), address(_governanceFactory));
    }

    /**
     * @param _govFactory the governance factory address
     * @param _sFactory the storage factory address
     * @param _mStorageFactory the meta storage factory address
     */
    function upgrade(
        address _govFactory,
        address _sFactory,
        address _mStorageFactory,
        uint8 _version
    ) public onlyOwner reinitializer(_version) {
        _storageFactory = StorageFactory(_sFactory);
        _metaStorageFactory = MetaStorageFactory(_mStorageFactory);
        _governanceFactory = GovernanceFactory(_govFactory);
        emit Upgraded(address(_storageFactory), address(_metaStorageFactory), address(_governanceFactory), _version);
    }

    /// @notice initialize and create a new builder context for this sender
    /// @return GovernanceBuilder this contract
    function aGovernance() external returns (GovernanceBuilder) {
        clear(msg.sender);
        emit GovernanceContractInitialized(msg.sender);
        return this;
    }

    /// @notice set the VoterClass to be used for the next constructed contract
    /// @param _classAddress the address of the VoterClass contract
    /// @return GovernanceBuilder this contract
    function withCommunityClassAddress(address _classAddress) external returns (GovernanceBuilder) {
        IERC165 erc165 = IERC165(_classAddress);
        if (!erc165.supportsInterface(type(CommunityClass).interfaceId)) revert CommunityClassRequired(_classAddress);
        return withCommunityClass(CommunityClass(_classAddress));
    }

    /// @notice set the VoterClass to be used for the next constructed contract
    /// @dev the type safe VoterClass for use within Solidity code
    /// @param _class the address of the VoterClass contract
    /// @return GovernanceBuilder this contract
    function withCommunityClass(CommunityClass _class) public returns (GovernanceBuilder) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.class = _class;
        emit GovernanceContractWithCommunityClass(msg.sender, address(_class), _class.name(), _class.version());
        return this;
    }

    /// @notice set the community name
    /// @param _name the name
    /// @return GovernanceBuilder this contract
    function withName(bytes32 _name) public returns (GovernanceBuilder) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.name = _name;
        emit GovernanceContractWithName(msg.sender, _name);
        return this;
    }

    /// @notice set the community url
    /// @param _url the url
    /// @return GovernanceBuilder this contract
    function withUrl(string memory _url) public returns (GovernanceBuilder) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.url = _url;
        emit GovernanceContractWithUrl(msg.sender, _url);
        return this;
    }

    /// @notice set the community description
    /// @dev limit 1k
    /// @param _description the description
    /// @return GovernanceBuilder this contract
    function withDescription(string memory _description) public returns (GovernanceBuilder) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.description = _description;
        emit GovernanceContractWithDescription(msg.sender, _description);
        return this;
    }

    /// @notice set the community information
    /// @dev this helper calls withName, withUrl and WithDescription
    /// @param _name the name
    /// @param _url the url
    /// @param _description the description
    /// @return GovernanceBuilder this contract
    function withDescription(bytes32 _name, string memory _url, string memory _description) external returns (GovernanceBuilder) {
        withName(_name);
        withUrl(_url);
        return withDescription(_description);
    }

    /// @notice build the specified contract
    /// @dev contructs a new contract and may require a large gas fee, does not reinitialize context
    /// @return governanceAddress address of the new Governance contract
    /// @return storageAddress address of the storage contract
    /// @return metaAddress address of the meta contract
    function build() external returns (address payable governanceAddress, address storageAddress, address metaAddress) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        Storage _storage = createStorage(_properties);
        TimeLocker _timeLock = createTimelock(_properties.class.minimumVoteDuration());
        MetaStorage _metaStore = _metaStorageFactory.create(_properties.name, _properties.url, _properties.description);
        transferOwnership(address(_metaStore), msg.sender);
        Governance _governance = _governanceFactory.create(_properties.class, _storage, _timeLock);
        address payable _governanceAddress = payable(address(_governance));
        transferOwnership(address(_timeLock), _governanceAddress);
        transferOwnership(address(_storage), _governanceAddress);
        _governanceContractRegistered[_governanceAddress] = true;
        address _storageAddress = address(_storage);
        address _metaAddress = address(_metaStore);
        address _timeAddress = address(_timeLock);
        emit GovernanceContractCreated(
            msg.sender,
            _properties.name,
            _storageAddress,
            _metaAddress,
            _timeAddress,
            _governanceAddress
        );
        return (_governanceAddress, _storageAddress, _metaAddress);
    }

    /// @notice identify a contract that was created by this builder
    /// @return bool True if contract was created by this builder
    function contractRegistered(address _contract) external view returns (bool) {
        return _governanceContractRegistered[_contract];
    }

    /// @notice clear and reset resources associated with sender build requests
    function reset() external {
        // overwrite to truncate data lifetime
        clear(msg.sender);
        delete _buildMap[msg.sender];
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    function transferOwnership(address _ownedObject, address _targetOwner) private {
        Ownable _ownableStorage = Ownable(_ownedObject);
        _ownableStorage.transferOwnership(_targetOwner);
    }

    function createTimelock(uint256 _minimumVoteDuration) private returns (TimeLocker) {
        uint256 _timeLockDelay = Math.max(_minimumVoteDuration, Constant.TIMELOCK_MINIMUM_DELAY);
        TimeLocker _timeLock = new TimeLock(_timeLockDelay);
        emit TimeLockCreated(address(_timeLock), _timeLockDelay);
        return _timeLock;
    }

    function createStorage(GovernanceProperties storage _properties) private returns (Storage) {
        if (address(_properties.class) == address(0x0)) revert CommunityClassRequired(address(_properties.class));
        Storage _storage = _storageFactory.create(_properties.class);
        return _storage;
    }

    function clear(address sender) internal {
        GovernanceProperties storage _properties = _buildMap[sender];
        _properties.class = CommunityClass(address(0x0));
        _properties.name = "";
        _properties.url = "";
        _properties.description = "";
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(OwnableInitializable).interfaceId ||
            interfaceId == type(Versioned).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function supportsInterface(address _ct, bytes4 _interfaceId) private view returns (bool) {
        IERC165 _erc165 = IERC165(_ct);
        return _erc165.supportsInterface(_interfaceId);
    }

    /// see UUPSUpgradeable
    function _authorizeUpgrade(address _caller) internal virtual override(UUPSUpgradeable) onlyOwner {
        emit UpgradeAuthorized(_caller, owner());
    }
}
