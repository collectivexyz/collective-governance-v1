// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../contracts/Storage.sol";
import "../contracts/StorageFactory.sol";
import "../contracts/StorageFactoryProxy.sol";
import "../contracts/VoterClassFactory.sol";
import "../contracts/access/Versioned.sol";

import "./TestData.sol";

contract StorageFactoryTest is Test {
    VoterClass private _class;
    StorageFactoryCreator private _storageFactoryInstance;
    StorageFactoryProxy private _factoryProxy;
    StorageFactoryCreator private _storageFactory;

    function setUp() public {
        VoterClassCreator _vcCreator = new VoterClassFactory();
        address vcAddress = _vcCreator.createOpenVote(1);
        _class = VoterClass(vcAddress);
        _storageFactoryInstance = new StorageFactory();
        _factoryProxy = new StorageFactoryProxy(address(_storageFactoryInstance));
        _storageFactory = StorageFactoryCreator(address(_factoryProxy));
    }

    function testSetupNewStorage() public {
        Storage _storage = _storageFactory.create(
            _class,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
        assertTrue(_storage.supportsInterface(type(Storage).interfaceId));
    }

    function testIsStorageOwner() public {
        Storage _storage = _storageFactory.create(
            _class,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
        Ownable _ownable = Ownable(address(_storage));
        assertEq(_ownable.owner(), address(this));
    }

    function testSupportsIERC165() public {
        bytes4 ifId = type(IERC165).interfaceId;
        assertTrue(_storageFactory.supportsInterface(ifId));
    }

    function testSupportsGovernanceFactoryCreator() public {
        bytes4 ifId = type(StorageFactoryCreator).interfaceId;
        assertTrue(_storageFactory.supportsInterface(ifId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_storageFactory.supportsInterface(ifId));
    }

    function testProxyUpgrade() public {
        UUPSUpgradeable __uups = UUPSUpgradeable(address(_factoryProxy));
        ForwardStorageFactory fsFactory = new ForwardStorageFactory();
        __uups.upgradeTo(address(fsFactory));
        ForwardStorageFactory fsByProxy = ForwardStorageFactory(address(_factoryProxy));
        // check upgraded
        assertTrue(fsByProxy.isUpgraded());
    }
}

contract ForwardStorageFactory is StorageFactory {
    function isUpgraded() public pure returns (bool) {
        return true;
    }
}
