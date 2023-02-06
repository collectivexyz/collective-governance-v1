// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../../contracts/storage/Storage.sol";
import "../../contracts/storage/StorageFactory.sol";
import "../../contracts/storage/StorageFactoryProxy.sol";
import "../../contracts/community/CommunityBuilder.sol";
import "../../contracts/access/Versioned.sol";

import "../../test/mock/TestData.sol";

contract StorageFactoryTest is Test {
    CommunityClass private _class;
    StorageFactory private _storageFactoryInstance;
    StorageFactoryProxy private _factoryProxy;
    StorageFactory private _storageFactory;

    function setUp() public {
        CommunityBuilder _vcCreator = new CommunityBuilder();
        address vcAddress = _vcCreator.aCommunity().asOpenCommunity().withQuorum(1).build();
        _class = CommunityClass(vcAddress);
        _storageFactoryInstance = new StorageFactory();
        _factoryProxy = new StorageFactoryProxy(address(_storageFactoryInstance));
        _storageFactory = StorageFactory(address(_factoryProxy));
    }

    function testSetupNewStorage() public {
        Storage _storage = _storageFactory.create(_class);
        assertTrue(_storage.supportsInterface(type(Storage).interfaceId));
    }

    function testIsStorageOwner() public {
        Storage _storage = _storageFactory.create(_class);
        Ownable _ownable = Ownable(address(_storage));
        assertEq(_ownable.owner(), address(this));
    }

    function testSupportsIERC165() public {
        bytes4 ifId = type(IERC165).interfaceId;
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
