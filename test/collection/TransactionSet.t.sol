// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { Transaction, TransactionSet, TransactionCollection, getHash } from "../../contracts/collection/TransactionSet.sol";
import { OneOwner } from "../../contracts/access/OneOwner.sol";

contract TransactionSetTest is Test {
    TransactionSet private _set;

    function setUp() public {
        _set = new TransactionSet();
    }

    function testAddGet() public {
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        uint256 index = _set.add(transaction);
        Transaction memory testValue = _set.get(index);
        assertEq(testValue.target, transaction.target);
        assertEq(testValue.value, transaction.value);
        assertEq(testValue.signature, transaction.signature);
        assertEq(testValue._calldata, transaction._calldata);
        assertEq(testValue.scheduleTime, transaction.scheduleTime);
        assertEq(abi.encode(testValue), abi.encode(transaction));
    }

    function testDuplicateAdd() public {
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        _set.add(transaction);
        vm.expectRevert(abi.encodeWithSelector(TransactionCollection.HashCollision.selector, getHash(transaction)));
        _set.add(transaction);
    }

    function testSize() public {
        for (uint256 i = 0; i < 10; ++i) {
            Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890 + i);
            _set.add(transaction);
        }
        assertEq(_set.size(), 10);
    }

    function testErase() public {
        for (uint256 i = 0; i < 10; ++i) {
            Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890 + i);
            _set.add(transaction);
        }
        Transaction memory tt = Transaction(address(0x123), 45, "six", "seven", 890);
        assertTrue(_set.erase(tt));
        assertFalse(_set.contains(tt));
    }

    function testEraseSize() public {
        for (uint256 i = 0; i < 10; ++i) {
            Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890 + i);
            _set.add(transaction);
        }
        Transaction memory tt = Transaction(address(0x123), 45, "six", "seven", 890);
        assertTrue(_set.erase(tt));
        assertEq(_set.size(), 9);
    }

    function testEraseIndex() public {
        Transaction memory tt = Transaction(address(0x123), 45, "six", "seven", 890);
        uint256 index = _set.add(tt);
        _set.erase(index);
        assertFalse(_set.contains(tt));
        assertEq(_set.size(), 0);
    }

    function testFind() public {
        Transaction memory tt = Transaction(address(0x123), 45, "six", "seven", 890);
        uint256 required = _set.add(tt);
        uint256 testValue = _set.find(tt);
        assertEq(testValue, required);
    }

    function testGetHash() public {
        Transaction memory tt = Transaction(address(0x123), 45, "six", "seven", 890);
        bytes32 expect = keccak256(abi.encode(tt));
        bytes32 computed = getHash(tt);
        assertEq(expect, computed);
    }

    function testGetZer0() public {
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        _set.add(transaction);
        vm.expectRevert(abi.encodeWithSelector(TransactionCollection.InvalidTransaction.selector, 0));
        _set.get(0);
    }

    function testGetInvalid() public {
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        _set.add(transaction);
        uint256 _maxIndex = _set.size() + 1;
        vm.expectRevert(abi.encodeWithSelector(TransactionCollection.InvalidTransaction.selector, _maxIndex));
        _set.get(_maxIndex);
    }

    function testGetAllowed() public {
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        _set.add(transaction);
        vm.prank(address(0x123));
        Transaction memory itrans = _set.get(1);
        assertEq(address(0x123), itrans.target);
    }

    function testAddProtected() public {
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        vm.expectRevert(abi.encodeWithSelector(OneOwner.NotOwner.selector, address(0x123)));
        vm.prank(address(0x123));
        _set.add(transaction);
    }

    function testEraseProtected() public {
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        _set.add(transaction);
        vm.expectRevert(abi.encodeWithSelector(OneOwner.NotOwner.selector, address(0x123)));
        vm.prank(address(0x123));
        _set.erase(transaction);
    }

    function testEraseIndexProtected() public {
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        _set.add(transaction);
        vm.expectRevert(abi.encodeWithSelector(OneOwner.NotOwner.selector, address(0x123)));
        vm.prank(address(0x123));
        _set.erase(1);
    }
}
