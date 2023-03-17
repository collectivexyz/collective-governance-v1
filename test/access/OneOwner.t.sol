// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { OneOwner } from "../../contracts/access/OneOwner.sol";

contract OneOwnerTest is Test {
    MockOwner private _owner;

    function setUp() public {
        _owner = new MockOwner();
    }

    function testOwnerIsSet() public {
        assertEq(address(this), _owner.owner());
    }

    function testOwnerIsRequired() public {
        vm.expectRevert(abi.encodeWithSelector(OneOwner.NotOwner.selector, address(0x123)));
        vm.prank(address(0x123));
        _owner.requireOwner();
    }
}

contract MockOwner is OneOwner {
    // solhint-disable-next-line no-empty-blocks
    function requireOwner() public onlyOwner {}
}
