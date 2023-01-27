// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

import "forge-std/Test.sol";

import "../../contracts/community/CommunityBuilder.sol";

import "../../contracts/access/Versioned.sol";
import "../../test/MockERC721.sol";
import "../../test/MockERC721Enum.sol";

contract CommunityClassERC721Test is Test {
    uint256 private constant _TOKENID = 0xf733b17d;
    address private constant _OWNER = address(0xffeeeeff);
    address private constant _NOTOWNER = address(0x55);

    IERC721 private _tokenContract;
    VoterClass private _class;

    function setUp() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_OWNER, _TOKENID);
        _tokenContract = merc721;
        CommunityBuilder _builder = new CommunityBuilder();
        address _classAddress = _builder.aCommunity().asErc721Community(address(_tokenContract)).withQuorum(1).build();
        _class = VoterClass(_classAddress);
    }

    function testDiscovery() public {
        vm.expectRevert(abi.encodeWithSelector(CommunityClassERC721.ERC721EnumerableRequired.selector, address(_tokenContract)));
        _class.discover(_OWNER);
    }

    function testDiscovery721Enumerable() public {
        MockERC721Enum merc721 = new MockERC721Enum();
        merc721.mintTo(_OWNER, _TOKENID);
        merc721.mintTo(_OWNER, _TOKENID + 1);
        merc721.mintTo(_OWNER, _TOKENID + 2);
        merc721.mintTo(_OWNER, _TOKENID + 3);
        _class = new CommunityClassERC721(
            address(merc721),
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        uint256[] memory tokenIdList = _class.discover(_OWNER);
        assertEq(tokenIdList.length, 4);
        for (uint256 i = 0; i < 4; i++) {
            assertEq(tokenIdList[i], _TOKENID + i);
        }
    }

    function testConfirmOwner() public {
        uint256 shareCount = _class.confirm(_OWNER, _TOKENID);
        assertEq(shareCount, 1);
    }

    function testFailConfirmNotOwner() public {
        _class.confirm(_NOTOWNER, _TOKENID);
    }

    function testOpenToPropose() public {
        assertTrue(_class.canPropose(_NOTOWNER));
    }

    function testWeight() public {
        assertEq(1, _class.weight());
    }

    function testFinal() public {
        assertTrue(_class.isFinal());
    }

    function testSupportsInterface() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(_erc165.supportsInterface(type(Mutable).interfaceId));
        assertTrue(_erc165.supportsInterface(type(IERC165).interfaceId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_class.supportsInterface(ifId));
    }

    function testName() public {
        assertEq("CommunityClassERC721", _class.name());
    }
}
