// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { Choice, ChoiceSet, ChoiceCollection, getHash } from "../../contracts/collection/ChoiceSet.sol";

contract ChoiceSetTest is Test {
    ChoiceSet private _set;

    function setUp() public {
        _set = new ChoiceSet();
    }

    function testAdd() public {
        Choice memory choice = Choice("a1", "a choice", 53, "2123", 22);
        uint256 index = _set.add(choice);
        Choice memory mm = _set.get(index);
        assertEq(abi.encode(mm), abi.encode(choice));
        assertEq(mm.name, choice.name);
        assertEq(mm.description, choice.description);
        assertEq(mm.transactionId, choice.transactionId);
        assertEq(mm.txHash, choice.txHash);
        assertEq(mm.voteCount, choice.voteCount);
    }

    function testIncrement() public {
        Choice memory choice = Choice("a1", "a choice", 53, "2123", 22);
        uint256 index = _set.add(choice);
        _set.incrementVoteCount(index);
        Choice memory mm = _set.get(index);
        assertEq(mm.voteCount, choice.voteCount + 1);
    }

    function testHash() public {
        Choice memory choice = Choice("a1", "a choice", 53, "2123", 22);
        bytes32 expect = keccak256(abi.encode(choice));
        bytes32 computed = getHash(choice);
        assertEq(computed, expect);
    }

    function testDuplicateForbidden() public {
        Choice memory choice = Choice("a1", "a choice", 53, "2123", 22);
        _set.add(choice);
        vm.expectRevert(abi.encodeWithSelector(ChoiceCollection.HashCollision.selector, getHash(choice)));
        _set.add(choice);
    }

    function testSize() public {
        for (uint256 i = 0; i < 27; ++i) {
            Choice memory choice = Choice(keccak256(abi.encode(i)), "a choice", 53, "2123", 22);
            _set.add(choice);
        }
        assertEq(_set.size(), 27);
    }

    function testErase() public {
        for (uint256 i = 0; i < 27; ++i) {
            Choice memory choice = Choice(keccak256(abi.encode(i)), "a choice", 53, "2123", 22);
            _set.add(choice);
        }
        Choice memory _m19 = Choice(keccak256(abi.encode(19)), "a choice", 53, "2123", 22);
        _set.erase(_m19);
        for (uint256 i = 0; i < 27; ++i) {
            if (i != 19) {
                Choice memory choice = Choice(keccak256(abi.encode(i)), "a choice", 53, "2123", 22);
                assertTrue(_set.contains(choice));
            }
        }
        assertFalse(_set.contains(_m19));
    }

    function testEraseSize() public {
        for (uint256 i = 0; i < 27; ++i) {
            Choice memory choice = Choice(keccak256(abi.encode(i)), "a choice", 53, "2123", 22);
            _set.add(choice);
        }
        Choice memory _m19 = Choice(keccak256(abi.encode(19)), "a choice", 53, "2123", 22);
        _set.erase(_m19);
        assertEq(_set.size(), 26);
    }

    function testEraseIndex() public {
        for (uint256 i = 0; i < 27; ++i) {
            Choice memory choice = Choice(keccak256(abi.encode(i)), "a choice", 53, "2123", 22);
            _set.add(choice);
        }
        _set.erase(27);
        assertEq(_set.size(), 26);
        Choice memory _m27 = Choice(keccak256(abi.encode(27)), "a choice", 53, "2123", 22);
        assertFalse(_set.contains(_m27));
    }

    function testContainsIndex() public {
        for (uint256 i = 0; i < 27; ++i) {
            Choice memory choice = Choice(keccak256(abi.encode(i)), "a choice", 53, "2123", 22);
            _set.add(choice);
        }
        for (uint256 i = 0; i < 27; ++i) {
            assertTrue(_set.contains(i + 1));
        }
    }

    function testFind() public {
        uint256 _index19 = 0;
        for (uint256 i = 0; i < 27; ++i) {
            Choice memory choice = Choice(keccak256(abi.encode(i)), "a choice", 53, "2123", 22);
            uint256 index = _set.add(choice);
            if (i == 19) {
                _index19 = index;
            }
        }
        uint256 found19 = _set.find(Choice(keccak256(abi.encode(19)), "a choice", 53, "2123", 22));
        assertEq(found19, _index19);
    }

    function testGetZer0() public {
        Choice memory choice = Choice("z1", "a choice", 53, "2123", 22);
        _set.add(choice);
        vm.expectRevert(abi.encodeWithSelector(ChoiceCollection.IndexInvalid.selector, 0));
        _set.get(0);
    }

    function testGetInvalid() public {
        Choice memory choice = Choice("z1", "a choice", 53, "2123", 22);
        _set.add(choice);
        uint256 _maxIndex = _set.size() + 1;
        vm.expectRevert(abi.encodeWithSelector(ChoiceCollection.IndexInvalid.selector, _maxIndex));
        _set.get(_maxIndex);
    }

    function testGetAllowed() public {
        Choice memory choice = Choice("z1", "a choice", 53, "2123", 22);
        _set.add(choice);
        vm.prank(address(0x123));
        Choice memory indexedChoice = _set.get(1);
        assertEq("z1", indexedChoice.name);
    }

    function testAddProtected() public {
        Choice memory choice = Choice("z1", "a choice", 53, "2123", 22);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x123));
        _set.add(choice);
    }

    function testEraseProtected() public {
        Choice memory choice = Choice("z1", "a choice", 53, "2123", 22);
        _set.add(choice);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x123));
        _set.erase(choice);
    }

    function testEraseIndexProtected() public {
        Choice memory choice = Choice("z1", "a choice", 53, "2123", 22);
        _set.add(choice);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x123));
        _set.erase(1);
    }
}
