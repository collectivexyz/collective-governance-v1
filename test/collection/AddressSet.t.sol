// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { AddressSet, AddressCollection } from "../../contracts/collection/AddressSet.sol";

contract AddressSetTest is Test {
    AddressSet private _set;

    function setUp() public {
        _set = new AddressSet();
    }

    function testAdd() public {
        address testAddr = address(0x1);
        uint256 index = _set.add(testAddr);
        assertEq(_set.get(index), testAddr);
    }

    function testAddDuplicate() public {
        address testAddr = address(0x1);
        _set.add(testAddr);
        vm.expectRevert(abi.encodeWithSelector(AddressCollection.DuplicateAddress.selector, testAddr));
        _set.add(testAddr);
        assertEq(_set.size(), 1);
    }

    function testSet() public {
        address testAddr = address(0x1);
        assertTrue(_set.set(testAddr));
        assertTrue(_set.contains(testAddr));
    }

    function testDuplicateSet() public {
        address testAddr = address(0x1);
        assertTrue(_set.set(testAddr));
        assertFalse(_set.set(testAddr));
        assertEq(_set.size(), 1);
    }

    function testContains() public {
        address testAddr = address(0x1);
        _set.add(testAddr);
        assertTrue(_set.contains(testAddr));
        assertFalse(_set.contains(address(0x0)));
    }

    function testSize() public {
        for (uint160 i = 0; i < 100; ++i) {
            _set.add(address(i));
        }
        assertEq(_set.size(), 100);
    }

    function testErase() public {
        for (uint160 i = 0; i < 100; ++i) {
            _set.add(address(i));
        }
        assertTrue(_set.erase(address(50)));
        for (uint160 i = 0; i < 100; ++i) {
            if (i != 50) {
                assertTrue(_set.contains(address(i)));
            }
        }
        assertFalse(_set.contains(address(50)));
        assertFalse(_set.erase(address(1000)));
    }

    function testEraseIndex() public {
        uint256 index = _set.add(address(0x100));
        assertTrue(_set.erase(index));
        assertEq(_set.size(), 0);
        assertFalse(_set.contains(address(0x100)));
    }

    function testEraseSize() public {
        for (uint160 i = 0; i < 100; ++i) {
            _set.add(address(i));
        }
        for (uint160 j = 0; j < 25; ++j) {
            assertTrue(_set.erase(address(j)));
        }
        assertEq(_set.size(), 75);
    }

    function testFind() public {
        uint256 required = _set.add(address(0x200));
        uint256 found = _set.find(address(0x200));
        assertEq(found, required);
    }

    function testGetZer0() public {
        address testAddr = address(0x1);
        _set.add(testAddr);
        vm.expectRevert(abi.encodeWithSelector(AddressCollection.IndexInvalid.selector, 0));
        _set.get(0);
    }

    function testGetInvalid() public {
        address testAddr = address(0x1);
        _set.add(testAddr);
        uint256 _maxIndex = _set.size() + 1;
        vm.expectRevert(abi.encodeWithSelector(AddressCollection.IndexInvalid.selector, _maxIndex));
        _set.get(_maxIndex);
    }

    function testGetAllowed() public {
        _set.add(address(0x1));
        vm.prank(address(0x123));
        assertEq(address(0x1), _set.get(1));
    }

    function testAddProtected() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x123));
        _set.add(address(0x123));
    }

    function testEraseProtected() public {
        _set.add(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x123));
        _set.erase(address(0x123));
    }

    function testEraseIndexProtected() public {
        _set.add(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x123));
        _set.erase(1);
    }
}
