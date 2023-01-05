// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../contracts/access/Versioned.sol";
import "../contracts/MetaStorageFactory.sol";

contract MetaStorageFactoryTest is Test {
    MetaFactoryCreator private _metaCreator;
    MetaStorage private _meta;

    function setUp() public {
        _metaCreator = new MetaStorageFactory();
        _meta = _metaCreator.create("acme inc", "https://github.com/collectivexyz/collective-governance-v1", "Universal Exports");
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
        assertTrue(_metaCreator.supportsInterface(ifId));
    }

    function testSupportsMetaFactoryCreator() public {
        bytes4 ifId = type(MetaFactoryCreator).interfaceId;
        assertTrue(_metaCreator.supportsInterface(ifId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_metaCreator.supportsInterface(ifId));
    }
}
