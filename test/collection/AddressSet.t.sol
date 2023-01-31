// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../../contracts/collection/AddressSet.sol";

contract AddressTest is Test {
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
        vm.expectRevert(abi.encodeWithSelector(AddressSet.DuplicateAddress.selector, testAddr));
        _set.add(testAddr);
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
        assertFalse(_set.contains(address(50)));
        assertFalse(_set.erase(address(1000)));
    }
}
