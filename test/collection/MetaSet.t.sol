// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { Meta, MetaSet, MetaCollection, getHash } from "../../contracts/collection/MetaSet.sol";
import { OneOwner } from "../../contracts/access/OneOwner.sol";

contract MetaSetTest is Test {
    MetaSet private _set;

    function setUp() public {
        _set = new MetaSet();
    }

    function testAdd() public {
        Meta memory meta = Meta("ziggy", "stardust");
        uint256 index = _set.add(meta);
        Meta memory mm = _set.get(index);
        assertEq(abi.encode(mm), abi.encode(meta));
        assertEq(mm.name, meta.name);
        assertEq(mm.value, meta.value);
    }

    function testHash() public {
        Meta memory meta = Meta("ziggy", "stardust");
        bytes32 expect = keccak256(abi.encode(meta));
        bytes32 computed = getHash(meta);
        assertEq(computed, expect);
    }

    function testDuplicateForbidden() public {
        Meta memory meta = Meta("ziggy", "stardust");
        _set.add(meta);
        vm.expectRevert(abi.encodeWithSelector(MetaCollection.HashCollision.selector, getHash(meta)));
        _set.add(meta);
    }

    function testSize() public {
        for (uint256 i = 0; i < 27; ++i) {
            Meta memory meta = Meta(keccak256(abi.encode(i)), "");
            _set.add(meta);
        }
        assertEq(_set.size(), 27);
    }

    function testErase() public {
        for (uint256 i = 0; i < 27; ++i) {
            Meta memory meta = Meta(keccak256(abi.encode(i)), "");
            _set.add(meta);
        }
        Meta memory _m19 = Meta(keccak256(abi.encode(19)), "");
        _set.erase(_m19);
        for (uint256 i = 0; i < 27; ++i) {
            if (i != 19) {
                Meta memory meta = Meta(keccak256(abi.encode(i)), "");
                assertTrue(_set.contains(meta));
            }
        }
        assertFalse(_set.contains(_m19));
    }

    function testEraseSize() public {
        for (uint256 i = 0; i < 27; ++i) {
            Meta memory meta = Meta(keccak256(abi.encode(i)), "");
            _set.add(meta);
        }
        Meta memory _m19 = Meta(keccak256(abi.encode(19)), "");
        _set.erase(_m19);
        assertEq(_set.size(), 26);
    }

    function testEraseIndex() public {
        for (uint256 i = 0; i < 27; ++i) {
            Meta memory meta = Meta(keccak256(abi.encode(i)), "");
            _set.add(meta);
        }
        _set.erase(27);
        assertEq(_set.size(), 26);
        Meta memory _m27 = Meta(keccak256(abi.encode(27)), "");
        assertFalse(_set.contains(_m27));
    }

    function testFind() public {
        uint256 _index19 = 0;
        for (uint256 i = 0; i < 27; ++i) {
            Meta memory meta = Meta(keccak256(abi.encode(i)), "");
            uint256 index = _set.add(meta);
            if (i == 19) {
                _index19 = index;
            }
        }
        uint256 found19 = _set.find(Meta(keccak256(abi.encode(19)), ""));
        assertEq(found19, _index19);
    }

    function testGetZer0() public {
        Meta memory meta = Meta("ziggy", "stardust");
        _set.add(meta);
        vm.expectRevert(abi.encodeWithSelector(MetaCollection.IndexInvalid.selector, 0));
        _set.get(0);
    }

    function testGetInvalid() public {
        Meta memory meta = Meta("ziggy", "stardust");
        _set.add(meta);
        uint256 _maxIndex = _set.size() + 1;
        vm.expectRevert(abi.encodeWithSelector(MetaCollection.IndexInvalid.selector, _maxIndex));
        _set.get(_maxIndex);
    }

    function testGetAllowed() public {
        Meta memory meta = Meta("ziggy", "stardust");
        _set.add(meta);
        vm.prank(address(0x123));
        Meta memory imeta = _set.get(1);
        assertEq("ziggy", imeta.name);
    }

    function testAddProtected() public {
        Meta memory meta = Meta("ziggy", "stardust");
        vm.expectRevert(abi.encodeWithSelector(OneOwner.NotOwner.selector, address(0x123)));
        vm.prank(address(0x123));
        _set.add(meta);
    }

    function testEraseProtected() public {
        Meta memory meta = Meta("ziggy", "stardust");
        _set.add(meta);
        vm.expectRevert(abi.encodeWithSelector(OneOwner.NotOwner.selector, address(0x123)));
        vm.prank(address(0x123));
        _set.erase(meta);
    }

    function testEraseIndexProtected() public {
        Meta memory meta = Meta("ziggy", "stardust");
        _set.add(meta);
        vm.expectRevert(abi.encodeWithSelector(OneOwner.NotOwner.selector, address(0x123)));
        vm.prank(address(0x123));
        _set.erase(1);
    }
}
