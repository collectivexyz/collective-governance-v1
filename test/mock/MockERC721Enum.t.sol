// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import { Test } from "forge-std/Test.sol";

import { MockERC721Enum } from "./MockERC721Enum.sol";

contract MockERC721EnumTest is Test {
    IERC721Enumerable private erc721;

    address private immutable _owner = address(0x11);
    address private immutable _nextowner = address(0x12);
    uint256 private immutable _tokenId1 = 0xf0;
    uint256 private immutable _tokenId2 = 0xf1;
    uint256 private immutable _tokenId3 = 0xf2;
    uint256 private immutable _tokenId4 = 0xf3;

    function setUp() public {
        MockERC721Enum merc721 = new MockERC721Enum();
        merc721.mintTo(_owner, _tokenId1);
        merc721.mintTo(_owner, _tokenId2);
        merc721.mintTo(_nextowner, _tokenId3);
        merc721.mintTo(_owner, _tokenId4);
        erc721 = merc721;
    }

    function testTotalSupply() public {
        assertEq(erc721.totalSupply(), 4);
    }

    function testOwnerIndex() public {
        assertEq(erc721.tokenOfOwnerByIndex(_owner, 0), _tokenId1);
        assertEq(erc721.tokenOfOwnerByIndex(_owner, 1), _tokenId2);
        assertEq(erc721.tokenOfOwnerByIndex(_owner, 2), _tokenId4);
        assertEq(erc721.tokenOfOwnerByIndex(_nextowner, 0), _tokenId3);
    }

    function testFailOwnerInvalidIndex(uint256 index) public view {
        vm.assume(index > 2);
        erc721.tokenOfOwnerByIndex(_owner, index);
    }

    function testTokenGlobalIndex() public {
        assertEq(erc721.tokenByIndex(0), _tokenId1);
        assertEq(erc721.tokenByIndex(1), _tokenId2);
        assertEq(erc721.tokenByIndex(2), _tokenId3);
        assertEq(erc721.tokenByIndex(3), _tokenId4);
    }

    function testFailTokenGlobalInvalidIndex(uint256 index) public view {
        vm.assume(index > 3);
        erc721.tokenByIndex(index);
    }

    function testIsERC721() public {
        bytes4 interfaceId = type(IERC721).interfaceId;
        assertTrue(erc721.supportsInterface(interfaceId));
    }

    function testIsERC721Enumerable() public {
        bytes4 interfaceId = type(IERC721Enumerable).interfaceId;
        assertTrue(erc721.supportsInterface(interfaceId));
    }
}
