// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../../contracts/collection/TransactionSet.sol";

contract AddressTest is Test {
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
    }

    function testDuplicateAdd() public {
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        _set.add(transaction);
        vm.expectRevert(abi.encodeWithSelector(TransactionSet.HashCollision.selector, getTxHash(transaction)));
        _set.add(transaction);
    }

    function testSetSize() public {
        for (uint256 i = 0; i < 10; ++i) {
            Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890 + i);
            _set.add(transaction);
        }
        assertEq(_set.size(), 10);
    }
}
