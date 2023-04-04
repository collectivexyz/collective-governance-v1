// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

import { Test } from "forge-std/Test.sol";

import { Storage } from "../../contracts/storage/Storage.sol";
import { StorageFactory } from "../../contracts/storage/StorageFactory.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { createCommunityBuilder } from "../../contracts/community/CommunityBuilderProxy.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";

import { TestData } from "../../test/mock/TestData.sol";

contract StorageFactoryTest is Test {
    address private constant _SUPERVISOR = address(0x1234);
    CommunityClass private _class;
    StorageFactory private _storageFactoryInstance;
    StorageFactory private _storageFactory;

    function setUp() public {
        CommunityBuilder _vcCreator = createCommunityBuilder();
        address vcAddress = _vcCreator.aCommunity().asOpenCommunity().withQuorum(1).withCommunitySupervisor(_SUPERVISOR).build();
        _class = CommunityClass(vcAddress);
        _storageFactory = new StorageFactory();
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

    function testSupportsInterfaceOwnable() public {
        bytes4 ifId = type(Ownable).interfaceId;
        assertTrue(_storageFactory.supportsInterface(ifId));
    }
}
