// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { Test } from "forge-std/Test.sol";

import { OwnableInitializable } from "../../contracts/access/OwnableInitializable.sol";

contract OwnableInitializableTest is Test {
    address private constant _OWNER = address(0xfffe);
    address private constant _OTHER = address(0xffff);

    OwnableTrinket private _ownable;

    function setUp() public {
        _ownable = new OwnableTrinket();
    }

    function testOwnerNotInitialized() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableInitializable.NotInitialized.selector));
        _ownable.owner();
    }

    function testTransferNotInitialized() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableInitializable.NotInitialized.selector));
        _ownable.owner();
    }

    function testOwnerModifierNotInitialized() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableInitializable.NotInitialized.selector));
        _ownable.checkOwner();
    }

    function testTransferNotOwner() public {
        _ownable.initialize();
        assertEq(_ownable.owner(), address(this));
        vm.expectRevert(abi.encodeWithSelector(OwnableInitializable.NotOwner.selector, _OTHER));
        vm.prank(_OTHER, _OTHER);
        _ownable.transferOwnership(_OTHER);
    }

    function testInitialization() public {
        _ownable.initialize();
        assertEq(_ownable.owner(), address(this));
    }

    function testTransferOwner() public {
        _ownable.initialize();
        _ownable.transferOwnership(_OTHER);
        assertEq(_ownable.owner(), _OTHER);
    }
}

// solhint-disable-next-line no-empty-blocks
contract OwnableTrinket is OwnableInitializable, Initializable {
    function initialize() public initializer {
        ownerInitialize(msg.sender);
    }

    // solhint-disable-next-line no-empty-blocks
    function checkOwner() public onlyOwner {}
}
