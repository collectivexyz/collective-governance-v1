// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { TreasuryBuilder } from "../../contracts/treasury/TreasuryBuilder.sol";
import { Treasury } from "../../contracts/treasury/Treasury.sol";
import { Vault } from "../../contracts/treasury/Vault.sol";
import { TimeLocker } from "../../contracts/treasury/TimeLocker.sol";
import { Constant } from "../../contracts/Constant.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";
import { getHash, Transaction } from "../../contracts/collection/TransactionSet.sol";

contract TreasuryTest is Test {
    address public constant _APP1 = address(0x1234);
    address public constant _APP2 = address(0x1235);
    address public constant _APP3 = address(0x1236);
    address public constant _DENIZEN1 = address(0x1237);
    address public constant _DENIZEN2 = address(0x1238);
    address public constant _NOBODY = address(0xffff);

    Treasury private _treasury;
    AddressCollection private _approver;

    function setUp() public {
        vm.clearMockedCalls();
        TreasuryBuilder _builder = new TreasuryBuilder();
        address payable treasAddy = _builder
            .aTreasury()
            .withMinimumApprovalRequirement(2)
            .withTimeLockDelay(Constant.TIMELOCK_MINIMUM_DELAY)
            .withApprover(_APP1)
            .withApprover(_APP2)
            .withApprover(_APP3)
            .build();
        _treasury = Treasury(treasAddy);
        vm.deal(_APP1, 20 ether);
        _treasury.deposit{ value: 20 ether }();
    }

    function testFallbackDeposit() public {
        vm.deal(_APP1, 100 ether);
        address payable treasAddr = payable(address(_treasury));
        vm.prank(_APP1);
        treasAddr.transfer(100 ether);
        // 20 sent in setup
        assertEq(treasAddr.balance, 120 ether);
    }

    function testFallbackDepositRequiredNonZero() public {
        vm.deal(_APP1, 100 ether);
        address payable treasAddr = payable(address(_treasury));
        vm.prank(_APP1);
        vm.expectRevert(abi.encodeWithSelector(Vault.NoDeposit.selector, _APP1));
        treasAddr.transfer(0 ether);
    }

    function testDepositAsPublicFallback() public {
        vm.deal(_APP1, 100 ether);
        vm.prank(_APP1);
        _treasury.deposit{ value: 100 ether }();
        // 20 sent in setup
        assertEq(_treasury.balance(), 120 ether);
    }

    function testDepositNonZero() public {
        vm.deal(_APP1, 100 ether);
        vm.prank(_APP1);
        vm.expectRevert(abi.encodeWithSelector(Vault.NoDeposit.selector, _APP1));
        _treasury.deposit{ value: 0 ether }();
    }

    function testHackApproverListFails() public {
        AddressCollection approverSet = _treasury._approverSet();
        vm.expectRevert("Ownable: caller is not the owner");
        approverSet.add(address(0x1236));
    }

    function testApproveRequiresMultisig() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        assertEq(_treasury.balance(_DENIZEN1), 0 ether);
    }

    function testNoDoubleApproval() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP1);
        vm.expectRevert(abi.encodeWithSelector(Vault.DuplicateApproval.selector, _APP1));
        _treasury.approve(_DENIZEN1, 1 ether);
    }

    function testBothApproversWork() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP2);
        _treasury.approve(_DENIZEN1, 1 ether);
        assertEq(_treasury.balance(_DENIZEN1), 1 ether);
    }

    function testOverApproverIsRevert() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP2);
        _treasury.approve(_DENIZEN1, 1 ether);
        assertEq(_treasury.balance(_DENIZEN1), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(Vault.TransactionInProgress.selector, _DENIZEN1));
        vm.prank(_APP3);
        _treasury.approve(_DENIZEN1, 1 ether);
    }

    function testAnotherApproverNotAllowed() public {
        vm.prank(_NOBODY);
        vm.expectRevert(abi.encodeWithSelector(Vault.NotApprover.selector, _NOBODY));
        _treasury.approve(_DENIZEN1, 1 ether);
    }

    function testApproveTooMuch() public {
        vm.prank(_APP1);
        vm.expectRevert(abi.encodeWithSelector(Vault.InsufficientBalance.selector, 30 ether, 20 ether));
        _treasury.approve(_DENIZEN1, 30 ether);
    }

    function testBothApproverMustAgree() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP2);
        vm.expectRevert(abi.encodeWithSelector(Vault.ApprovalNotMatched.selector, _APP2, 10 ether, 1 ether));
        _treasury.approve(_DENIZEN1, 10 ether);
    }

    function testCallerPayee() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP2);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.warp(getBlockTimestamp() + Constant.TIMELOCK_MINIMUM_DELAY);
        vm.prank(_DENIZEN1);
        _treasury.pay();
        assertEq(_DENIZEN1.balance, 1 ether);
    }

    function testAnyonePaying() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP2);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.warp(getBlockTimestamp() + Constant.TIMELOCK_MINIMUM_DELAY);
        _treasury.transferTo(_DENIZEN1);
        assertEq(_DENIZEN1.balance, 1 ether);
        assertEq(_treasury.balance(), 19 ether);
    }

    function testEarlyPaymentFails() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP2);
        uint approvalTime = getBlockTimestamp();
        _treasury.approve(_DENIZEN1, 1 ether);
        uint transactionTime = approvalTime + Constant.TIMELOCK_MINIMUM_DELAY;
        vm.warp(transactionTime - 1);
        Transaction memory trans = Transaction(_DENIZEN1, 1 ether, "", "", transactionTime);
        bytes32 txHash = getHash(trans);
        vm.expectRevert(abi.encodeWithSelector(TimeLocker.TransactionLocked.selector, txHash, trans.scheduleTime));
        _treasury.transferTo(_DENIZEN1);
        assertEq(_treasury.balance(), 20 ether);
    }

    function testLatePaymentFails() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP2);
        uint approvalTime = getBlockTimestamp();
        _treasury.approve(_DENIZEN1, 1 ether);
        uint transactionTime = approvalTime + Constant.TIMELOCK_MINIMUM_DELAY;
        vm.warp(transactionTime + Constant.TIMELOCK_GRACE_PERIOD + 1);
        Transaction memory trans = Transaction(_DENIZEN1, 1 ether, "", "", transactionTime);
        bytes32 txHash = getHash(trans);
        vm.expectRevert(abi.encodeWithSelector(TimeLocker.TransactionStale.selector, txHash));
        _treasury.transferTo(_DENIZEN1);
        assertEq(_treasury.balance(), 20 ether);
    }

    function testScheduleAnotherPaymentWhilePendingFails() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP2);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP1);
        vm.expectRevert(abi.encodeWithSelector(Vault.TransactionInProgress.selector, _DENIZEN1));
        _treasury.approve(_DENIZEN1, 2 ether);
    }

    function testLateCancelButRetryPaymentOkay() public {
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        vm.prank(_APP2);
        uint approvalTime = getBlockTimestamp();
        _treasury.approve(_DENIZEN1, 1 ether);
        uint transactionTime = approvalTime + Constant.TIMELOCK_MINIMUM_DELAY;
        vm.warp(transactionTime + Constant.TIMELOCK_GRACE_PERIOD + 1);
        assertEq(_treasury.balance(_DENIZEN1), 1 ether);
        // payment will fail now so cancel instead
        vm.prank(_APP2);
        _treasury.cancel(_DENIZEN1);
        assertEq(_treasury.balance(_DENIZEN1), 0 ether);
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
    }

    function testJustPaymeFails() public {
        vm.expectRevert(abi.encodeWithSelector(Vault.NotPending.selector, _DENIZEN1));
        vm.prank(_DENIZEN1);
        _treasury.pay();
    }

    function testPaymeViaFallbackAlsoDisallowed() public {
        vm.expectRevert(abi.encodeWithSelector(Vault.NotPending.selector, _DENIZEN1));
        address payable treasAddy = payable(address(_treasury));
        vm.prank(_DENIZEN1);
        // solhint-disable-next-line avoid-low-level-calls
        (bool sent, ) = treasAddy.call{ value: 1 ether }("Send money!");
        assertFalse(sent);
    }

    function testBalance() public {
        assertEq(20 ether, _treasury.balance());
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 7 ether);
        vm.prank(_APP2);
        _treasury.approve(_DENIZEN1, 7 ether);
        assertEq(_treasury.balance(_DENIZEN1), 7 ether);
        assertEq(_treasury.balance(), 20 ether);
        vm.warp(getBlockTimestamp() + Constant.TIMELOCK_MINIMUM_DELAY);
        vm.prank(_DENIZEN1);
        _treasury.pay();
        assertEq(_DENIZEN1.balance, 7 ether);
        assertEq(_treasury.balance(_DENIZEN1), 0 ether);
        assertEq(_treasury.balance(), 13 ether);
    }

    function testMultiRequiresApprover() public {
        bytes[] memory signature = new bytes[](1);
        signature[0] = "";
        uint scheduleTime = getBlockTimestamp();
        vm.expectRevert(abi.encodeWithSelector(Vault.NotApprover.selector, _NOBODY));
        vm.prank(_NOBODY);
        _treasury.approveMulti(_DENIZEN1, 1 ether, scheduleTime, signature);
    }

    function testMultiExcessiveQuantity() public {
        bytes[] memory signature = new bytes[](1);
        signature[0] = "";
        uint scheduleTime = getBlockTimestamp();
        vm.expectRevert(abi.encodeWithSelector(Vault.InsufficientBalance.selector, 21 ether, 20 ether));
        vm.prank(_APP1);
        _treasury.approveMulti(_DENIZEN1, 21 ether, scheduleTime, signature);
    }

    function getBlockTimestamp() private view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }
}
