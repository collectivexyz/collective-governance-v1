// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

import "forge-std/Test.sol";
import "../contracts/VoterClassERC721.sol";
import "./MockERC721.sol";
import "./MockERC721Enum.sol";

contract VoterClassERC721Test is Test {
    uint256 immutable _tokenId = 0xf733b17d;
    address immutable _owner = address(0xffeeeeff);
    address immutable _notowner = address(0x55);
    address immutable _nobody = address(0x0);
    IERC721 _tokenContract;
    VoterClass _class;

    function setUp() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_owner, _tokenId);
        _tokenContract = merc721;
        _class = new VoterClassERC721(address(_tokenContract), 1);
    }

    function testDiscovery() public {
        vm.expectRevert("ERC-721 Enumerable required");
        _class.discover(_owner);
    }

    function testDiscovery721Enumerable() public {
        MockERC721Enum merc721 = new MockERC721Enum();
        merc721.mintTo(_owner, _tokenId);
        merc721.mintTo(_owner, _tokenId + 1);
        merc721.mintTo(_owner, _tokenId + 2);
        merc721.mintTo(_owner, _tokenId + 3);
        _class = new VoterClassERC721(address(merc721), 1);
        uint256[] memory tokenIdList = _class.discover(_owner);
        assertEq(tokenIdList.length, 4);
        for (uint256 i = 0; i < 4; i++) {
            assertEq(tokenIdList[i], _tokenId + i);
        }
    }

    function testConfirmOwner() public {
        uint256 shareCount = _class.confirm(_owner, _tokenId);
        assertEq(shareCount, 1);
    }

    function testFailConfirmNobody() public {
        _class.confirm(_nobody, _tokenId);
    }

    function testFailConfirmNotOwner() public {
        _class.confirm(_notowner, _tokenId);
    }

    function testWeight() public {
        assertEq(1, _class.weight());
    }

    function testFinal() public {
        assertTrue(_class.isFinal());
    }
}
