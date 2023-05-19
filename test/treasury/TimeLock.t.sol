// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Transaction, getHash } from "../../contracts/collection/TransactionSet.sol";
import { TimeLocker } from "../../contracts/treasury/TimeLocker.sol";
import { TimeLock } from "../../contracts/treasury/TimeLock.sol";
import { FlagSet, ValueSet } from "../mock/FlagSet.sol";

contract TimeLockTest is Test {
    uint256 private constant _WEEK_DELAY = 7 days;
    address private constant _FUNCTION = address(0x7);
    address private constant _NOT_OWNER = address(0xffee);
    address private constant _TYCOON = address(0x1001);
    address private constant _JOE = address(0x1002);
    // solhint-disable-next-line var-name-mixedcase
    address private immutable _OWNER = address(0xffdd);

    TimeLock private _timeLock;

    function setUp() public {
        vm.clearMockedCalls();
        _timeLock = new TimeLock(_WEEK_DELAY);
        _timeLock.transferOwnership(_OWNER);
    }

    function testMinimumRequiredDelay(uint256 delayDelta) public {
        vm.assume(delayDelta > 0 && delayDelta < Constant.TIMELOCK_MINIMUM_DELAY);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.RequiredDelayNotInRange.selector,
                Constant.TIMELOCK_MINIMUM_DELAY - delayDelta,
                Constant.TIMELOCK_MINIMUM_DELAY,
                Constant.TIMELOCK_MAXIMUM_DELAY
            )
        );
        new TimeLock(Constant.TIMELOCK_MINIMUM_DELAY - delayDelta);
    }

    function testMaximumRequiredDelay(uint256 delayDelta) public {
        vm.assume(
            delayDelta > Constant.TIMELOCK_MAXIMUM_DELAY && delayDelta < Constant.UINT_MAX - Constant.TIMELOCK_MAXIMUM_DELAY
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.RequiredDelayNotInRange.selector,
                Constant.TIMELOCK_MAXIMUM_DELAY + delayDelta,
                Constant.TIMELOCK_MINIMUM_DELAY,
                Constant.TIMELOCK_MAXIMUM_DELAY
            )
        );
        new TimeLock(Constant.TIMELOCK_MAXIMUM_DELAY + delayDelta);
    }

    function testTransactionEarlyForTimeLock(uint256 timeDelta) public {
        vm.assume(timeDelta > 1 && timeDelta < _WEEK_DELAY);
        uint256 currentTime = block.timestamp;
        Transaction memory transaction = Transaction(_FUNCTION, 7, "abc", "data", currentTime + _WEEK_DELAY - timeDelta);
        bytes32 txHash = getHash(transaction);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.TimestampNotInLockRange.selector,
                txHash,
                currentTime,
                transaction.scheduleTime,
                currentTime + _WEEK_DELAY,
                currentTime + _WEEK_DELAY + Constant.TIMELOCK_GRACE_PERIOD
            )
        );
        vm.prank(_OWNER);
        _timeLock.queueTransaction(
            transaction.target,
            transaction.value,
            transaction.signature,
            transaction._calldata,
            transaction.scheduleTime
        );
    }

    function testTransactionLateForTimeLock(uint256 timeDelta) public {
        vm.assume(timeDelta > 0 && timeDelta < (Constant.UINT_MAX - _WEEK_DELAY - Constant.TIMELOCK_GRACE_PERIOD));
        uint256 currentTime = block.timestamp;
        uint256 scheduleTime = currentTime + _WEEK_DELAY + Constant.TIMELOCK_GRACE_PERIOD;
        Transaction memory transaction = Transaction(_FUNCTION, 7, "abc", "data", scheduleTime + timeDelta);
        bytes32 txHash = getHash(transaction);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.TimestampNotInLockRange.selector,
                txHash,
                currentTime,
                transaction.scheduleTime,
                currentTime + _WEEK_DELAY,
                currentTime + _WEEK_DELAY + Constant.TIMELOCK_GRACE_PERIOD
            )
        );

        vm.prank(_OWNER);
        _timeLock.queueTransaction(
            transaction.target,
            transaction.value,
            transaction.signature,
            transaction._calldata,
            transaction.scheduleTime
        );
    }

    function testOwnerMustQueueTransaction() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_NOT_OWNER);
        _timeLock.queueTransaction(address(100), 7, "abc", "data", block.timestamp + _WEEK_DELAY);
    }

    function testQueueTransactionHash() public {
        vm.prank(_OWNER);
        Transaction memory transaction = Transaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        bytes32 txHash = _timeLock.queueTransaction(
            transaction.target,
            transaction.value,
            transaction.signature,
            transaction._calldata,
            transaction.scheduleTime
        );
        assertTrue(_timeLock._queuedTransaction(txHash));
        bytes32 expect = getHash(transaction);
        assertEq(txHash, expect);
    }

    function testQueuedTransactionGetterHash() public {
        vm.prank(_OWNER);
        bytes32 txHash = _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertTrue(_timeLock.queuedTransaction(txHash));
    }

    function testQueueTransactionDoubleQueue() public {
        vm.prank(_OWNER);
        bytes32 txHash = _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertTrue(_timeLock._queuedTransaction(txHash));
        vm.expectRevert(abi.encodeWithSelector(TimeLocker.QueueCollision.selector, txHash));
        vm.prank(_OWNER);
        _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
    }

    function testCancelTransaction() public {
        vm.prank(_OWNER);
        bytes32 txHash = _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertTrue(_timeLock._queuedTransaction(txHash));
        vm.prank(_OWNER);
        _timeLock.cancelTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertFalse(_timeLock._queuedTransaction(txHash));
    }

    function testDoubleCancel() public {
        vm.prank(_OWNER);
        bytes32 txHash = _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertTrue(_timeLock._queuedTransaction(txHash));
        vm.prank(_OWNER);
        _timeLock.cancelTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        vm.expectRevert(abi.encodeWithSelector(TimeLocker.NotInQueue.selector, txHash));

        vm.prank(_OWNER);
        _timeLock.cancelTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
    }

    function testCancelTransactionRequiresOwner() public {
        vm.prank(_OWNER);
        bytes32 txHash = _timeLock.queueTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
        assertTrue(_timeLock._queuedTransaction(txHash));
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_NOT_OWNER);
        _timeLock.cancelTransaction(_FUNCTION, 7, "abc", "data", block.timestamp + _WEEK_DELAY);
    }

    function testExecuteFlag() public {
        FlagSet flag = new FlagSet();
        assertFalse(flag.isSet());
        address flagMock = address(flag);
        bytes memory _call = abi.encodeWithSelector(flag.set.selector);
        uint256 etaOfLock = block.timestamp + _WEEK_DELAY;
        vm.prank(_OWNER);
        bytes32 txHash = _timeLock.queueTransaction(flagMock, 0, "", _call, etaOfLock);
        vm.warp(block.timestamp + _WEEK_DELAY);
        assertTrue(_timeLock._queuedTransaction(txHash));
        _timeLock.executeTransaction(flagMock, 0, "", _call, etaOfLock);
        assertFalse(_timeLock._queuedTransaction(txHash));
        assertTrue(flag.isSet());
    }

    function testExecuteTransaction(uint256 systemClock) public {
        uint256 currentTime = block.timestamp;
        vm.assume(systemClock > _WEEK_DELAY && systemClock < _WEEK_DELAY + Constant.TIMELOCK_GRACE_PERIOD - 1 minutes);
        vm.deal(_TYCOON, 1 ether);
        vm.prank(_TYCOON);
        payable(_timeLock).transfer(1 ether);
        uint256 etaOfLock = currentTime + systemClock;
        vm.prank(_OWNER);
        bytes32 txHash = _timeLock.queueTransaction(_JOE, 1 ether, "", "", etaOfLock);
        vm.warp(etaOfLock + Constant.TIMELOCK_GRACE_PERIOD);
        assertTrue(_timeLock._queuedTransaction(txHash));
        _timeLock.executeTransaction(_JOE, 1 ether, "", "", etaOfLock);
        assertFalse(_timeLock._queuedTransaction(txHash));
        assertEq(_JOE.balance, 1 ether);
    }

    function testExecuteDuringLockPeriod() public {
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory _calldata = abi.encodeWithSelector(flag.set.selector);
        uint256 etaOfLock = block.timestamp + _WEEK_DELAY;
        vm.prank(_OWNER);
        bytes32 txHash = _timeLock.queueTransaction(flagMock, 0, "", _calldata, etaOfLock);
        assertTrue(_timeLock._queuedTransaction(txHash));
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(abi.encodeWithSelector(TimeLocker.TransactionLocked.selector, txHash, etaOfLock));
        vm.prank(_OWNER);
        _timeLock.executeTransaction(flagMock, 0, "", _calldata, etaOfLock);
    }

    function testTransferCoin() public {
        vm.deal(_TYCOON, 10 gwei);
        vm.prank(_TYCOON);
        payable(_timeLock).transfer(10 gwei);
        assertEq(_TYCOON.balance, 0);
        uint256 scheduleTime = block.timestamp + _WEEK_DELAY;
        vm.prank(_OWNER);
        _timeLock.queueTransaction(_JOE, 10 gwei, "", "", scheduleTime);
        vm.warp(scheduleTime);
        vm.prank(_OWNER);
        _timeLock.executeTransaction(_JOE, 10 gwei, "", "", scheduleTime);
        assertEq(_JOE.balance, 10 gwei);
    }

    function testFallbackNotAllowed() public {
        vm.deal(_JOE, 1 ether);
        vm.prank(_JOE);
        payable(_timeLock).transfer(1 ether);
        vm.expectRevert(abi.encodeWithSelector(TimeLocker.NotPermitted.selector, _JOE));
        vm.prank(_JOE);
        // solhint-disable-next-line avoid-low-level-calls
        (bool ok, bytes memory retData) = address(_timeLock).call("fallback()");
        // unreachable but solc warns without it
        assertTrue(ok);
        emit log_bytes(retData);
    }

    function testExecuteArbitraryFunctionCall() public {
        ValueSet valueSet = new ValueSet();
        address valueAddress = address(valueSet);
        bytes memory _calldata = abi.encode(_JOE, 13);
        uint256 etaOfLock = block.timestamp + _WEEK_DELAY;
        vm.prank(_OWNER);
        _timeLock.queueTransaction(valueAddress, 0, "set(address,uint256)", _calldata, etaOfLock);
        vm.warp(etaOfLock + Constant.TIMELOCK_GRACE_PERIOD - 1);
        vm.prank(_OWNER);
        _timeLock.executeTransaction(valueAddress, 0, "set(address,uint256)", _calldata, etaOfLock);
        assertEq(valueSet.valueOf(_JOE), 13);
    }
}
