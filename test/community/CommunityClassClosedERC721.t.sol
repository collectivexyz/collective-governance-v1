// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../../contracts/community/CommunityBuilder.sol";
import "../../contracts/access/Versioned.sol";
import "../../test/mock/MockERC721.sol";
import "../../test/mock/MockERC721Enum.sol";

contract CommunityClassClosedERC721Test is Test {
    uint256 private constant _TOKENID = 0xf733b17d;
    address private constant _OWNER = address(0xffeeeeff);
    address private constant _PARTOWNER = address(0xffeeeefe);
    address private constant _NOTOWNER = address(0x55);

    IERC721 private _tokenContract;
    CommunityClass private _class;

    function setUp() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_OWNER, _TOKENID);
        merc721.mintTo(_OWNER, _TOKENID + 1);
        merc721.mintTo(_PARTOWNER, _TOKENID + 2);
        _tokenContract = merc721;
        CommunityBuilder _builder = new CommunityBuilder();
        address _classAddress = _builder.aCommunity().asClosedErc721Community(address(_tokenContract), 2).withQuorum(1).build();
        _class = CommunityClass(_classAddress);
    }

    function testOpenToMemberPropose() public {
        assertTrue(_class.canPropose(_OWNER));
    }

    function testNotOpenToPartOwnerPropose() public {
        assertFalse(_class.canPropose(_PARTOWNER));
    }

    function testClosedToPropose() public {
        assertFalse(_class.canPropose(_NOTOWNER));
    }

    function testFinal() public {
        assertTrue(_class.isFinal());
    }

    function testName() public {
        assertEq("CommunityClassERC721", _class.name());
    }
}
