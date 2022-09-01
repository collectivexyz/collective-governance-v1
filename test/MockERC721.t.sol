// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

import "forge-std/Test.sol";
import "./MockERC721.sol";

contract MockERC721Test is Test {
    IERC721 private erc721;

    address private immutable _owner = address(0x11);
    uint256 private immutable _tokenId = 0xff;

    function setUp() public {
        erc721 = new MockERC721(_owner, _tokenId);
    }

    function testBalanceOf() public {
        assertEq(erc721.balanceOf(_owner), 1);
    }

    function testOwnerOf() public {
        vm.prank(_owner);
        assertEq(erc721.ownerOf(_tokenId), _owner);
    }
}
