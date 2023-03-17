// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { Test } from "forge-std/Test.sol";

import { Versioned } from "../../contracts/access/Versioned.sol";
import { MetaStorage } from "../../contracts/storage/MetaStorage.sol";
import { MetaStorageFactory } from "../../contracts/storage/MetaStorageFactory.sol";

contract MetaStorageFactoryTest is Test {
    MetaStorageFactory private _metaFactory;

    MetaStorage private _meta;

    function setUp() public {
        _metaFactory = new MetaStorageFactory();
        _meta = _metaFactory.create("acme inc", "https://github.com/collectivexyz/collective-governance-v1", "Universal Exports");
    }

    function testCreateMeta() public {
        assertEq(_meta.community(), "acme inc");
        assertEq(_meta.url(), "https://github.com/collectivexyz/collective-governance-v1");
        assertEq(_meta.description(), "Universal Exports");
    }

    function testCreateMetaOwner() public {
        Ownable _ownable = Ownable(address(_meta));
        assertEq(_ownable.owner(), address(this));
    }

    function testSupportsIERC165() public {
        bytes4 ifId = type(IERC165).interfaceId;
        assertTrue(_metaFactory.supportsInterface(ifId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_metaFactory.supportsInterface(ifId));
    }
}
