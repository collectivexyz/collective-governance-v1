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

    // approve example
    uint256 public constant _SCHEDULE_TIME = 1686160218;
    bytes public constant _SIGNATURE_1 =
        hex"0591ecf5c3aecc544245ebbe863ed9e36f354b0331bb83a4ba1893192e15c8d25813f1ea3dc22fe0258a7883144d97b5c252ee34b01354cd98c1c70cce510f6e1b";

    bytes public constant _SIGNATURE_2 =
        hex"1c9798fe3276ec599e9f293f3f183ac6685ccc1c163c0c1d0121095099a3576649701700919dc05f920b0edb2f9b4a13b6aabb897721d0cf0067045bfed09a7d1c";

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
            .withApprover(address(0xE43588937075dBDB9AEa91099b82eAC358640228))
            .withApprover(address(0xB3a2D68AF3ab42a79222b5c2922bc3f980Ff4A7E))
            .build();
        _treasury = Treasury(treasAddy);
        vm.deal(_APP1, 20 ether);
        vm.prank(_APP1);
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

    function testMultiSigApproval() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        assertEq(_treasury.balance(_DENIZEN1), 0 ether);
        bytes[] memory sigList = prepareSigList();
        vm.prank(_APP1);
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
        assertEq(_treasury.balance(_DENIZEN1), 10 ether);
    }

    function testMultiSigApprovalAllowsBothApprovers() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        assertEq(_treasury.balance(_DENIZEN1), 0 ether);
        bytes[] memory sigList = prepareSigList();
        vm.prank(_APP2);
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
        assertEq(_treasury.balance(_DENIZEN1), 10 ether);
    }

    function testMultiSigApprovalMayNotBePending() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        bytes[] memory sigList = prepareSigList();
        vm.prank(_APP1);
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
        vm.prank(_APP1);
        vm.expectRevert(abi.encodeWithSelector(Vault.TransactionInProgress.selector, _DENIZEN1));
        _treasury.approveMulti(_DENIZEN1, 1 ether, _SCHEDULE_TIME, sigList);
    }

    function testMultiSigRequiresApprover() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        bytes[] memory sigList = prepareSigList();
        vm.prank(_NOBODY);
        vm.expectRevert(abi.encodeWithSelector(Vault.NotApprover.selector, _NOBODY));
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
    }

    function testMultiSigBreaksTheBank() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        bytes[] memory sigList = prepareSigList();
        vm.prank(_APP1);
        vm.expectRevert(abi.encodeWithSelector(Vault.InsufficientBalance.selector, 100 ether, 20 ether));
        _treasury.approveMulti(_DENIZEN1, 100 ether, _SCHEDULE_TIME, sigList);
    }

    function testMultiSigInvalidSignature() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        bytes[] memory sigList = prepareSigList();
        sigList[
            1
        ] = hex"5352511d887f5026e0a012ea2b8c01a3e2f052957b966e761fe4bea3317e60917b8a93192739c24ed54a647a6096c978edf351772c484a5a0edf3d4d3263faef1b";
        vm.prank(_APP1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Vault.SignatureNotAccepted.selector,
                _APP1,
                address(0x6C2843E9C7438dA6Db0c6c70762DF7567cbE6519)
            )
        );
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
    }

    function testMultiSigDuplicateSignature() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        bytes[] memory sigList = prepareSigList();
        sigList[0] = sigList[1];
        vm.prank(_APP1);
        vm.expectRevert(
            abi.encodeWithSelector(Vault.DuplicateApproval.selector, address(0xB3a2D68AF3ab42a79222b5c2922bc3f980Ff4A7E))
        );
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
    }

    function testApproveAndApproveMulti() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        assertEq(_treasury.balance(_DENIZEN1), 0 ether);
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 10 ether);
        bytes[] memory sigList = new bytes[](1);
        sigList[0] = _SIGNATURE_1;
        vm.prank(_APP1);
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
        assertEq(_treasury.balance(_DENIZEN1), 10 ether);
    }

    function testApproveAndApproveMultiWithBadScheduleTime() public {
        assertEq(_treasury.balance(_DENIZEN1), 0 ether);
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MAXIMUM_DELAY);
        uint scheduleTime = _SCHEDULE_TIME - 1;
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 10 ether);
        bytes[] memory sigList = new bytes[](1);
        sigList[0] = _SIGNATURE_1;
        vm.prank(_APP1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Vault.SignatureNotAccepted.selector,
                _APP1,
                address(0x961Be0E1910D533157A635593d11Cc8EC478afAb)
            )
        );
        _treasury.approveMulti(_DENIZEN1, 10 ether, scheduleTime, sigList);
    }

    function testApproveAndApproveMultiWithIncreasedScheduleTime() public {
        assertEq(_treasury.balance(_DENIZEN1), 0 ether);
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY - 1);
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 10 ether);
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        bytes[] memory sigList = new bytes[](1);
        sigList[0] = _SIGNATURE_1;
        vm.prank(_APP1);
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
        assertEq(_treasury.balance(_DENIZEN1), 10 ether);
    }

    function testApproveAndApproveMultiWithDecreasedScheduleTime() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY + 1);
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 10 ether);
        bytes[] memory sigList = new bytes[](1);
        sigList[0] = _SIGNATURE_1;
        Transaction memory transaction = Transaction(_DENIZEN1, 10 ether, "", "", _SCHEDULE_TIME);
        bytes32 txHash = getHash(transaction);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.TimestampNotInLockRange.selector,
                txHash,
                _SCHEDULE_TIME,
                _SCHEDULE_TIME + 1,
                _SCHEDULE_TIME + Constant.TIMELOCK_GRACE_PERIOD + 1
            )
        );
        vm.prank(_APP1);
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
    }

    function testApproveAndApproveMultiDoesNotMatch() public {
        vm.warp(_SCHEDULE_TIME - Constant.TIMELOCK_MINIMUM_DELAY);
        vm.prank(_APP1);
        _treasury.approve(_DENIZEN1, 1 ether);
        bytes[] memory sigList = new bytes[](1);
        sigList[0] = _SIGNATURE_1;
        vm.prank(_APP1);
        vm.expectRevert(abi.encodeWithSelector(Vault.ApprovalNotMatched.selector, _APP1, 10 ether, 1 ether));
        _treasury.approveMulti(_DENIZEN1, 10 ether, _SCHEDULE_TIME, sigList);
    }

    function getBlockTimestamp() private view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    function prepareSigList() private pure returns (bytes[] memory) {
        bytes[] memory sigList = new bytes[](2);
        sigList[0] = _SIGNATURE_1;
        sigList[1] = _SIGNATURE_2;
        return sigList;
    }
}
