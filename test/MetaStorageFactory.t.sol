// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../contracts/MetaStorageFactory.sol";

contract MetaStorageFactoryTest is Test {
    function testCreateMeta() public {
        MetaStorage _meta = new MetaStorageFactory().createMeta(
            "acme inc",
            "https://github.com/collectivexyz/collective-governance-v1",
            "Universal Exports"
        );
        assertEq(_meta.community(), "acme inc");
        assertEq(_meta.url(), "https://github.com/collectivexyz/collective-governance-v1");
        assertEq(_meta.description(), "Universal Exports");
    }

    function testCreateMetaOwner() public {
        MetaStorage _meta = new MetaStorageFactory().createMeta(
            "acme inc",
            "https://github.com/collectivexyz/collective-governance-v1",
            "Universal Exports"
        );
        Ownable _ownable = Ownable(address(_meta));
        assertEq(_ownable.owner(), address(this));
    }
}
