// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { Test } from "forge-std/Test.sol";

import { Storage } from "../../contracts/storage/Storage.sol";
import { StorageFactory } from "../../contracts/storage/StorageFactory.sol";
import { StorageFactoryProxy } from "../../contracts/storage/StorageFactoryProxy.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";

import { TestData } from "../../test/mock/TestData.sol";

contract StorageFactoryTest is Test {
    address private constant _SUPERVISOR = address(0x1234);
    CommunityClass private _class;
    StorageFactory private _storageFactoryInstance;
    StorageFactoryProxy private _factoryProxy;
    StorageFactory private _storageFactory;

    function setUp() public {
        CommunityBuilder _vcCreator = new CommunityBuilder();
        address vcAddress = _vcCreator.aCommunity().asOpenCommunity().withQuorum(1).withCommunitySupervisor(_SUPERVISOR).build();
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
