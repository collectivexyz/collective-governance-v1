// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../contracts/MetaStorage.sol";
import "../contracts/MetaStorageFactory.sol";
import "./TestData.sol";

contract MetaStorageTest is Test {
    MetaStorage private _storage;

    uint256 private constant META_ID = 7;
    address private constant NOT_OWNER = address(0x1);

    function setUp() public {
        vm.clearMockedCalls();
        _storage = new MetaStorageFactory().createMeta(
            "acme inc",
            "https://github.com/collectivexyz/collective-governance-v1",
            "Universal Exports"
        );
    }

    function testCommunityName() public {
        assertEq(_storage.community(), "acme inc");
    }

    function testCommunityUrl() public {
        assertEq(_storage.url(), "https://github.com/collectivexyz/collective-governance-v1");
    }

    function testCommunityDescription() public {
        assertEq(_storage.description(), "Universal Exports");
    }

    function testDescribe() public {
        _storage.describe(META_ID, "https://collective.xyz", "description");
        assertEq(_storage.url(META_ID), "https://collective.xyz");
        assertEq(_storage.description(META_ID), "description");
    }

    function testSetMetaNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(NOT_OWNER);
        _storage.describe(META_ID, "https://collective.xyz", "");
    }

    function testDescribeUrlTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.UrlExceedsDataLimit.selector, META_ID));
        _storage.describe(META_ID, _TEST_STRING, "");
    }

    function testDescribeDescriptionTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.DescriptionExceedsDataLimit.selector, META_ID));
        _storage.describe(META_ID, "", _TEST_STRING);
    }

    function testMetaCountInitialValue() public {
        _storage.describe(META_ID, "", "");
        assertEq(_storage.metaCount(META_ID), 0);
    }

    function testMetaCount() public {
        for (uint256 i = 0; i < 10; i++) {
            _storage.addMeta(META_ID, "a", "1");
        }
        assertEq(_storage.metaCount(META_ID), 10);
    }

    function testAddMeta() public {
        uint256 m1 = _storage.addMeta(META_ID, "a", "1");
        uint256 m2 = _storage.addMeta(META_ID, "b", "2");
        (bytes32 m1name, string memory m1value) = _storage.getMeta(META_ID, m1);
        assertEq(m1name, "a");
        assertEq(m1value, "1");
        (bytes32 m2name, string memory m2value) = _storage.getMeta(META_ID, m2);
        assertEq(m2name, "b");
        assertEq(m2value, "2");
    }

    function testAddMetaNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(NOT_OWNER);
        _storage.addMeta(META_ID, "a", "1");
    }

    function testAddMetaValueTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.ValueExceedsDataLimit.selector, META_ID));
        _storage.addMeta(META_ID, "a", _TEST_STRING);
    }

    function testSupportsInterfaceMetaStorage() public {
        bytes4 ifId = type(MetaStorage).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
    }

    function testSupportsInterfaceOwnable() public {
        bytes4 ifId = type(Ownable).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
    }

    function testSupportsInterfaceERC165() public {
        bytes4 ifId = type(IERC165).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
    }

    function testUrlTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.CommunityUrlExceedsDataLimit.selector));
        new CollectiveMetaStorage("", _TEST_STRING, "");
    }

    function testDescriptionTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.CommunityDescriptionExceedsDataLimit.selector));
        new CollectiveMetaStorage("", "", _TEST_STRING);
    }
}
