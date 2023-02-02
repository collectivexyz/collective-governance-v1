// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable var-name-mixedcase
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../../contracts/storage/MetaStorage.sol";
import "../../contracts/storage/MetaStorageFactory.sol";
import "../../contracts/access/Versioned.sol";
import "../../test/mock/TestData.sol";

contract MetaStorageTest is Test {
    MetaStorage private _storage;

    uint256 private constant META_ID = 7;
    address private constant NOT_OWNER = address(0x1);

    function setUp() public {
        vm.clearMockedCalls();
        _storage = new MetaStorageFactory().create(
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

    function testDescribeBadId() public {
        _storage.describe(META_ID, "https://collective.xyz", "description");
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.IndexInvaliddataId.selector, META_ID + 1));
        _storage.description(META_ID + 1);
    }

    function testUrlBadID() public {
        _storage.describe(META_ID, "https://collective.xyz", "description");
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.IndexInvaliddataId.selector, META_ID + 1));
        _storage.url(META_ID + 1);
    }

    function testSetMetaNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(NOT_OWNER);
        _storage.describe(META_ID, "https://collective.xyz", "");
    }

    function testDescribeUrlTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.StringSizeLimit.selector, Constant.len(_TEST_STRING)));
        _storage.describe(META_ID, _TEST_STRING, "");
    }

    function testDescribeDescriptionTooLarge() public {
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.StringSizeLimit.selector, Constant.len(_TEST_STRING)));
        _storage.describe(META_ID, "", _TEST_STRING);
    }

    function testMetaCountInitialValue() public {
        _storage.describe(META_ID, "", "");
        assertEq(_storage.metaCount(META_ID), 0);
    }

    function testMetaCount() public {
        _storage.describe(META_ID, "", "");
        for (uint256 i = 0; i < 10; i++) {
            _storage.addMeta(META_ID, keccak256(abi.encode(i)), "1");
        }
        assertEq(_storage.metaCount(META_ID), 10);
    }

    function testAddMeta() public {
        _storage.describe(META_ID, "", "");
        uint256 m1 = _storage.addMeta(META_ID, "a", "1");
        uint256 m2 = _storage.addMeta(META_ID, "b", "2");
        Meta memory m1meta = _storage.getMeta(META_ID, m1);
        assertEq(m1meta.name, "a");
        assertEq(m1meta.value, "1");
        Meta memory m2meta = _storage.getMeta(META_ID, m2);
        assertEq(m2meta.name, "b");
        assertEq(m2meta.value, "2");
    }

    function testAddMetaRequiresDescribe() public {
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.IndexInvaliddataId.selector, META_ID));
        _storage.addMeta(META_ID, "a", "1");
    }

    function testZeroNotAllowedForMetaId() public {
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.IndexInvaliddataId.selector, 0));
        _storage.describe(0, "aaa", "1111");
    }

    function testAddMetaNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(NOT_OWNER);
        _storage.addMeta(META_ID, "a", "1");
    }

    function testAddMetaValueTooLarge() public {
        _storage.describe(META_ID, "", "");
        string memory _TEST_STRING = TestData.pi1kplus();
        vm.expectRevert(abi.encodeWithSelector(MetaStorage.StringSizeLimit.selector, Constant.len(_TEST_STRING)));
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

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
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
