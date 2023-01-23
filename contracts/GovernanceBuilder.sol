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

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../contracts/Constant.sol";
import "../contracts/GovernanceFactoryCreator.sol";
import "../contracts/GovernanceFactory.sol";
import "../contracts/GovernanceFactoryProxy.sol";
import "../contracts/GovernanceCreator.sol";
import "../contracts/community/CommunityClass.sol";
import "../contracts/community/CommunityClassNullObject.sol";
import "../contracts/storage/Storage.sol";
import "../contracts/storage/StorageFactory.sol";
import "../contracts/storage/StorageFactoryProxy.sol";
import "../contracts/storage/MetaStorage.sol";
import "../contracts/storage/MetaFactoryCreator.sol";
import "../contracts/storage/MetaStorageFactory.sol";
import "../contracts/storage/MetaStorageFactoryProxy.sol";
import "../contracts/access/Versioned.sol";
import "../contracts/access/VersionedContract.sol";

/// @title Governance GovernanceCreator implementation
/// @notice This builder supports creating new instances of the Collective Governance Contract
contract GovernanceBuilder is GovernanceCreator, VersionedContract, ERC165, Ownable {
    string public constant NAME = "collective governance builder";

    mapping(address => GovernanceProperties) private _buildMap;

    /// @dev implement the null object pattern requring voter class to be valid
    CommunityClass private immutable _voterClassNull;

    StorageFactoryCreator public immutable _storageFactory;
    StorageFactoryProxy public immutable _storageFactoryProxy;

    MetaFactoryCreator public immutable _metaStorageFactory;
    MetaStorageFactoryProxy public immutable _metaStorageFactoryProxy;

    GovernanceFactoryCreator public immutable _governanceFactory;
    GovernanceFactoryProxy public immutable _governanceFactoryProxy;

    mapping(address => bool) public _governanceContractRegistered;

    constructor() {
        _voterClassNull = new CommunityClassNullObject();
        StorageFactoryCreator storageFactory = new StorageFactory();
        _storageFactoryProxy = new StorageFactoryProxy(address(storageFactory));
        _storageFactory = StorageFactoryCreator(address(_storageFactoryProxy));
        MetaFactoryCreator metaStorageFactory = new MetaStorageFactory();
        _metaStorageFactoryProxy = new MetaStorageFactoryProxy(address(metaStorageFactory));
        _metaStorageFactory = MetaFactoryCreator(address(_metaStorageFactoryProxy));
        GovernanceFactoryCreator governanceFactory = new GovernanceFactory();
        _governanceFactoryProxy = new GovernanceFactoryProxy(address(governanceFactory));
        _governanceFactory = GovernanceFactoryCreator(address(_governanceFactoryProxy));
    }

    /// @notice initialize and create a new builder context for this sender
    /// @return GovernanceCreator this contract
    function aGovernance() external returns (GovernanceCreator) {
        clear(msg.sender);
        emit GovernanceContractInitialized(msg.sender);
        return this;
    }

    /// @notice add a supervisor to the supervisor list for the next constructed contract contract
    /// @dev maintains an internal list which increases with every call
    /// @param _supervisor the address of the wallet representing a supervisor for the project
    /// @return GovernanceCreator this contract
    function withSupervisor(address _supervisor) external returns (GovernanceCreator) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.supervisorList.push(_supervisor);
        emit GovernanceContractWithSupervisor(msg.sender, _supervisor);
        return this;
    }

    /// @notice set the VoterClass to be used for the next constructed contract
    /// @param _classAddress the address of the VoterClass contract
    /// @return GovernanceCreator this contract
    function withCommunityClassAddress(address _classAddress) external returns (GovernanceCreator) {
        IERC165 erc165 = IERC165(_classAddress);
        if (!erc165.supportsInterface(type(CommunityClass).interfaceId)) revert CommunityClassRequired(_classAddress);
        return withCommunityClass(CommunityClass(_classAddress));
    }

    /// @notice set the VoterClass to be used for the next constructed contract
    /// @dev the type safe VoterClass for use within Solidity code
    /// @param _class the address of the VoterClass contract
    /// @return GovernanceCreator this contract
    function withCommunityClass(CommunityClass _class) public returns (GovernanceCreator) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.class = _class;
        emit GovernanceContractwithCommunityClass(msg.sender, address(_class), _class.name(), _class.version());
        return this;
    }

    /// @notice set the community name
    /// @param _name the name
    /// @return GovernanceCreator this contract
    function withName(bytes32 _name) public returns (GovernanceCreator) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.name = _name;
        emit GovernanceContractWithName(msg.sender, _name);
        return this;
    }

    /// @notice set the community url
    /// @param _url the url
    /// @return GovernanceCreator this contract
    function withUrl(string memory _url) public returns (GovernanceCreator) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.url = _url;
        emit GovernanceContractWithUrl(msg.sender, _url);
        return this;
    }

    /// @notice set the community description
    /// @dev limit 1k
    /// @param _description the description
    /// @return GovernanceCreator this contract
    function withDescription(string memory _description) public returns (GovernanceCreator) {
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
    /// @return GovernanceCreator this contract
    function withDescription(bytes32 _name, string memory _url, string memory _description) external returns (GovernanceCreator) {
        withName(_name);
        withUrl(_url);
        return withDescription(_description);
    }

    /// @notice setup gas rebate parameters
    /// @param _gasUsed the maximum gas used for rebate
    /// @param _baseFee the maximum base fee for rebate
    /// @return GovernanceCreator this contract
    function withGasRebate(uint256 _gasUsed, uint256 _baseFee) external returns (GovernanceCreator) {
        GovernanceProperties storage _properties = _buildMap[msg.sender];
        _properties.maxGasUsed = _gasUsed;
        _properties.maxBaseFee = _baseFee;
        return this;
    }

    /// @notice build the specified contract
    /// @dev contructs a new contract and may require a large gas fee, does not reinitialize context
    /// @return governanceAddress address of the new Governance contract
    /// @return storageAddress address of the storage contract
    /// @return metaAddress address of the meta contract
    function build() external returns (address payable governanceAddress, address storageAddress, address metaAddress) {
        address _creator = msg.sender;
        GovernanceProperties storage _properties = _buildMap[_creator];
        Storage _storage = createStorage(_properties);
        TimeLocker _timeLock = createTimelock(_properties.class.minimumVoteDuration());
        MetaStorage _metaStore = _metaStorageFactory.create(_properties.name, _properties.url, _properties.description);
        Governance _governance = _governanceFactory.create(
            _properties.supervisorList,
            _properties.class,
            _storage,
            _metaStore,
            _timeLock,
            _properties.maxGasUsed,
            _properties.maxBaseFee
        );
        address payable _governanceAddress = payable(address(_governance));
        transferOwnership(address(_metaStore), _governanceAddress);
        transferOwnership(address(_timeLock), _governanceAddress);
        transferOwnership(address(_storage), _governanceAddress);
        _governanceContractRegistered[_governanceAddress] = true;
        address _storageAddress = address(_storage);
        address _metaAddress = address(_metaStore);
        address _timeAddress = address(_timeLock);
        emit GovernanceContractCreated(
            _creator,
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

    /// @notice upgrade factories
    /// @dev owner required
    /// @param _governanceAddr The address of the governance factory
    /// @param _storageAddr The address of the storage factory
    function upgrade(address _governanceAddr, address _storageAddr, address _metaAddr) external onlyOwner {
        if (!supportsInterface(_governanceAddr, type(GovernanceFactoryCreator).interfaceId))
            revert GovernanceFactoryRequired(_governanceAddr);
        if (!supportsInterface(_storageAddr, type(StorageFactoryCreator).interfaceId))
            revert StorageFactoryRequired(_storageAddr);
        if (!supportsInterface(_metaAddr, type(MetaFactoryCreator).interfaceId)) revert MetaStorageFactoryRequired(_metaAddr);
        StorageFactoryCreator _storage = StorageFactoryCreator(_storageAddr);
        MetaFactoryCreator _meta = MetaFactoryCreator(_metaAddr);
        GovernanceFactoryCreator _creator = GovernanceFactoryCreator(_governanceAddr);
        uint32 version = _creator.version();
        if (version > _storage.version()) revert StorageVersionMismatch(_storageAddr, version, _storage.version());
        if (version > _meta.version()) revert MetaVersionMismatch(_storageAddr, version, _meta.version());

        UUPSUpgradeable _upgradeableStorage = UUPSUpgradeable(address(_storageFactoryProxy));
        _upgradeableStorage.upgradeTo(_storageAddr);

        UUPSUpgradeable _upgradeableMeta = UUPSUpgradeable(address(_metaStorageFactoryProxy));
        _upgradeableMeta.upgradeTo(_metaAddr);

        UUPSUpgradeable _upgradeableGovernance = UUPSUpgradeable(address(_governanceFactoryProxy));
        _upgradeableGovernance.upgradeTo(_governanceAddr);
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
        if (address(_properties.class) == address(_voterClassNull)) revert CommunityClassRequired(address(_properties.class));
        Storage _storage = _storageFactory.create(_properties.class);
        return _storage;
    }

    function clear(address sender) internal {
        GovernanceProperties storage _properties = _buildMap[sender];
        _properties.class = _voterClassNull;
        _properties.supervisorList = new address[](0);
        _properties.maxGasUsed = Constant.MAXIMUM_REBATE_GAS_USED;
        _properties.maxBaseFee = Constant.MAXIMUM_REBATE_BASE_FEE;
        _properties.name = "";
        _properties.url = "";
        _properties.description = "";
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(GovernanceCreator).interfaceId ||
            interfaceId == type(Ownable).interfaceId ||
            interfaceId == type(Versioned).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function supportsInterface(address _ct, bytes4 _interfaceId) private view returns (bool) {
        IERC165 _erc165 = IERC165(_ct);
        return _erc165.supportsInterface(_interfaceId);
    }
}
