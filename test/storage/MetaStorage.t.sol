// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable var-name-mixedcase
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Meta } from "../../contracts/collection/MetaSet.sol";
import { MetaStorage } from "../../contracts/storage/MetaStorage.sol";
import { MappedMetaStorage } from "../../contracts/storage/MappedMetaStorage.sol";
import { MetaStorageFactory } from "../../contracts/storage/MetaStorageFactory.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { TestData } from "../../test/mock/TestData.sol";

contract MetaStorageTest is Test {
    uint256 private constant META_ID = 7;
    address private constant NOT_OWNER = address(0x1);

    MetaStorage private _meta;

    function setUp() public {
        vm.clearMockedCalls();
        _meta = new MetaStorageFactory().create(
            "acme inc",
            "https://github.com/collectivexyz/collective-governance-v1",
            "Universal Exports"
        );
    }

    function testCommunityName() public {
        assertEq(_meta.community(), "acme inc");
    }

    function testCommunityUrl() public {
        assertEq(_meta.url(), "https://github.com/collectivexyz/collective-governance-v1");
    }

    function testCommunityDescription() public {
        assertEq(_meta.description(), "Universal Exports");
    }

    function testDescribe() public {
        _meta.describe(META_ID, "https://collective.xyz", "description");
        assertEq(_meta.url(META_ID), "https://collective.xyz");
        assertEq(_meta.description(META_ID), "description");
    }

    function testDescribeBadId() public {
        _meta.describe(META_ID, "https://collective.xyz", "description");
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.IndexInvaliddataId.selector, META_ID + 1));
        _meta.description(META_ID + 1);
    }

    function testUrlBadID() public {
        _meta.describe(META_ID, "https://collective.xyz", "description");
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.IndexInvaliddataId.selector, META_ID + 1));
        _meta.url(META_ID + 1);
    }

    function testSetMetaNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(NOT_OWNER);
        _meta.describe(META_ID, "https://collective.xyz", "");
    }

    function testDescribeUrlTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.StringSizeLimit.selector, Constant.len(_TEST_STRING)));
        _meta.describe(META_ID, _TEST_STRING, "");
    }

    function testDescribeDescriptionTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.StringSizeLimit.selector, Constant.len(_TEST_STRING)));
        _meta.describe(META_ID, "", _TEST_STRING);
    }

    function testMetaCountInitialValue() public {
        _meta.describe(META_ID, "", "");
        assertEq(_meta.size(META_ID), 0);
    }

    function testMetaCount() public {
        _meta.describe(META_ID, "", "");
        for (uint256 i = 0; i < 10; i++) {
            _meta.add(META_ID, keccak256(abi.encode(i)), "1");
        }
        assertEq(_meta.size(META_ID), 10);
    }

    function testAddMeta() public {
        _meta.describe(META_ID, "", "");
        uint256 m1 = _meta.add(META_ID, "a", "1");
        uint256 m2 = _meta.add(META_ID, "b", "2");
        Meta memory m1meta = _meta.get(META_ID, m1);
        assertEq(m1meta.name, "a");
        assertEq(m1meta.value, "1");
        Meta memory m2meta = _meta.get(META_ID, m2);
        assertEq(m2meta.name, "b");
        assertEq(m2meta.value, "2");
    }

    function testAddMetaRequiresDescribe() public {
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.IndexInvaliddataId.selector, META_ID));
        _meta.add(META_ID, "a", "1");
    }

    function testZeroNotAllowedForMetaId() public {
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.IndexInvaliddataId.selector, 0));
        _meta.describe(0, "aaa", "1111");
    }

    function testAddMetaNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(NOT_OWNER);
        _meta.add(META_ID, "a", "1");
    }

    function testAddMetaValueTooLarge() public {
        _meta.describe(META_ID, "", "");
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.StringSizeLimit.selector, Constant.len(_TEST_STRING)));
        _meta.add(META_ID, "a", _TEST_STRING);
    }

    function testSupportsInterfaceMetaStorage() public {
        bytes4 ifId = type(MetaStorage).interfaceId;
        assertTrue(_meta.supportsInterface(ifId));
    }

    function testSupportsInterfaceOwnable() public {
        bytes4 ifId = type(Ownable).interfaceId;
        assertTrue(_meta.supportsInterface(ifId));
    }

    function testSupportsInterfaceERC165() public {
        bytes4 ifId = type(IERC165).interfaceId;
        assertTrue(_meta.supportsInterface(ifId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_meta.supportsInterface(ifId));
    }

    function testUrlTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.StringSizeLimit.selector, Constant.len(_TEST_STRING)));
        new MappedMetaStorage("", _TEST_STRING, "");
    }

    function testDescriptionTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.StringSizeLimit.selector, Constant.len(_TEST_STRING)));
        new MappedMetaStorage("", "", _TEST_STRING);
    }
}
