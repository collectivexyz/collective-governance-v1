// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../contracts/TimeLock.sol";
import "./FlagSet.sol";

contract TimeLockTest is Test {
    uint256 private constant _WEEK_DELAY = 7 days;
    address private constant _FUNCTION = address(0x7);
    address private constant _NOT_OWNER = address(0xffee);
    // solhint-disable-next-line var-name-mixedcase
    address private immutable _OWNER = address(this);

    TimeLock private _timeLock;

    function setUp() public {
        vm.clearMockedCalls();
        _timeLock = new TimeLock(_WEEK_DELAY);
    }

    function testTransactionDuringTimeLock() public {
        vm.expectRevert("Scheduled during time lock");
        _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp);
    }

    function testOwnerMustQueueTransaction() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_NOT_OWNER);
        _timeLock.queueTransaction(address(100), 7, "abc", "data", block.timestamp + _WEEK_DELAY);
    }

    function testQueueTransactionHash() public {
        bytes32 hashValue = _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertTrue(_timeLock._queuedTransaction(hashValue));
        assertEq(hashValue, 0xfb5a0fa7bd3bcd62232b1089ddbf45e63aa6d00e6cdf09f48ce3bb8d034746a2);
    }

    function testCancelTransaction() public {
        bytes32 hashValue = _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertTrue(_timeLock._queuedTransaction(hashValue));
        _timeLock.cancelTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertFalse(_timeLock._queuedTransaction(hashValue));
    }

    function testCancelTransactionRequiresOwner() public {
        bytes32 hashValue = _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertTrue(_timeLock._queuedTransaction(hashValue));
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_NOT_OWNER);
        _timeLock.cancelTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
    }

    function testExecuteTransaction() public {
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 eta = block.timestamp + _WEEK_DELAY;
        bytes32 hashValue = _timeLock.queueTransaction(flagMock, 0, "", data, eta);
        assertTrue(_timeLock._queuedTransaction(hashValue));
        vm.warp(block.timestamp + _WEEK_DELAY);
        _timeLock.executeTransaction(flagMock, 0, "", data, eta);
        assertFalse(_timeLock._queuedTransaction(hashValue));
        assertTrue(flag.isSet());
    }
}
