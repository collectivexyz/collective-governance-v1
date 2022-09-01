// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "forge-std/Test.sol";
import "../contracts/VoterClassERC721.sol";
import "./MockERC721.sol";

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

    function testFailDiscovery() public view {
        _class.discover(_owner);
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

    function testFailConfirmNotOwnerDirect() public {
        vm.prank(_owner);
        _class.confirm(_owner, _tokenId);
    }

    function testWeight() public {
        assertEq(1, _class.weight());
    }
}
