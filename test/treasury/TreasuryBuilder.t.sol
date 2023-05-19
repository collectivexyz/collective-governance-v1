// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { TreasuryBuilder } from "../../contracts/treasury/TreasuryBuilder.sol";
import { Treasury } from "../../contracts/treasury/Treasury.sol";
import { Constant } from "../../contracts/Constant.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";

contract TreasuryBuilderTest is Test {
    TreasuryBuilder private _builder;

    function setUp() public {
        vm.clearMockedCalls();
        _builder = new TreasuryBuilder();
    }

    function testApproverSet() public {
        address payable _treasuryAddress = _builder
            .aTreasury()
            .withMinimumApprovalRequirement(2)
            .withTimeLockDelay(Constant.TIMELOCK_MINIMUM_DELAY)
            .withApprover(address(0x1234))
            .withApprover(address(0x1235))
            .build();
        Treasury treasury = Treasury(_treasuryAddress);
        assertTrue(treasury._approverSet().contains(address(0x1234)));
        assertTrue(treasury._approverSet().contains(address(0x1235)));
        assertEq(2, treasury._minimumApprovalCount());
    }

    function testApproverRequirementMustBePossibleToMeet() public {
        _builder
            .aTreasury()
            .withMinimumApprovalRequirement(3)
            .withTimeLockDelay(Constant.TIMELOCK_MINIMUM_DELAY)
            .withApprover(address(0x1234))
            .withApprover(address(0x1235));
        vm.expectRevert(abi.encodeWithSelector(TreasuryBuilder.RequiresAdditionalApprovers.selector, address(this), 2, 3));
        _builder.build();
    }

    function testApproverRequirementMustIncludeOneApprover() public {
        _builder.aTreasury().withTimeLockDelay(Constant.TIMELOCK_MINIMUM_DELAY).withApprover(address(0x1234));
        vm.expectRevert(abi.encodeWithSelector(TreasuryBuilder.AtLeastOneApprovalIsRequired.selector, address(this)));
        _builder.build();
    }

    function testTimeLockDelayAboveMinimum() public {
        _builder
            .aTreasury()
            .withMinimumApprovalRequirement(1)
            .withTimeLockDelay(Constant.TIMELOCK_MINIMUM_DELAY - 1)
            .withApprover(address(0x1234));
        vm.expectRevert(
            abi.encodeWithSelector(
                TreasuryBuilder.TimeLockDelayIsNotPermitted.selector,
                address(this),
                Constant.TIMELOCK_MINIMUM_DELAY - 1,
                Constant.TIMELOCK_MINIMUM_DELAY
            )
        );
        _builder.build();
    }

    function testTimeLockDelayBelowMaximum() public {
        _builder
            .aTreasury()
            .withMinimumApprovalRequirement(1)
            .withTimeLockDelay(Constant.TIMELOCK_MAXIMUM_DELAY + 1)
            .withApprover(address(0x1234));
        vm.expectRevert(
            abi.encodeWithSelector(
                TreasuryBuilder.TimeLockDelayIsNotPermitted.selector,
                address(this),
                Constant.TIMELOCK_MAXIMUM_DELAY + 1,
                Constant.TIMELOCK_MAXIMUM_DELAY
            )
        );
        _builder.build();
    }

    function testClearRemovesSettings() public {
        _builder.aTreasury().withMinimumApprovalRequirement(1);
        _builder.clear();
        _builder.withTimeLockDelay(Constant.TIMELOCK_MINIMUM_DELAY).withApprover(address(0x1234));
        vm.expectRevert(abi.encodeWithSelector(TreasuryBuilder.AtLeastOneApprovalIsRequired.selector, address(this)));
        _builder.build();
    }
}
