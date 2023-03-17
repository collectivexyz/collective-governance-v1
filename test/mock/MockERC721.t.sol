// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";

import { Test } from "forge-std/Test.sol";
import { MockERC721 } from "../mock/MockERC721.sol";

contract MockERC721Test is Test {
    IERC721 private erc721;

    address private immutable _owner = address(0x11);
    address private immutable _nextowner = address(0x12);
    uint256 private immutable _tokenId = 0xff;

    function setUp() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_owner, _tokenId);
        erc721 = merc721;
    }

    function testBalanceOf() public {
        assertEq(erc721.balanceOf(_owner), 1);
    }

    function testOwnerOf() public {
        vm.prank(_owner);
        assertEq(erc721.ownerOf(_tokenId), _owner);
    }

    function testTransfer() public {
        assertEq(erc721.ownerOf(_tokenId), _owner);
        vm.prank(_owner);
        erc721.transferFrom(_owner, _nextowner, _tokenId);
        assertEq(erc721.ownerOf(_tokenId), _nextowner);
        assertEq(erc721.balanceOf(_owner), 0);
        assertEq(erc721.balanceOf(_nextowner), 1);
    }

    function testIsERC721() public {
        bytes4 interfaceId = type(IERC721).interfaceId;
        assertTrue(erc721.supportsInterface(interfaceId));
    }

    function testIsERC721Enumerable() public {
        bytes4 interfaceId = type(IERC721Enumerable).interfaceId;
        assertFalse(erc721.supportsInterface(interfaceId));
    }
}
