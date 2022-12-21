// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../contracts/VoterClassClosedERC721.sol";

import "../contracts/access/Upgradeable.sol";
import "./MockERC721.sol";
import "./MockERC721Enum.sol";

contract VoterClassClosedERC721Test is Test {
    uint256 private constant _TOKENID = 0xf733b17d;
    address private constant _OWNER = address(0xffeeeeff);
    address private constant _PARTOWNER = address(0xffeeeefe);
    address private constant _NOTOWNER = address(0x55);

    IERC721 private _tokenContract;
    VoterClass private _class;

    function setUp() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_OWNER, _TOKENID);
        merc721.mintTo(_OWNER, _TOKENID + 1);
        merc721.mintTo(_PARTOWNER, _TOKENID + 2);
        _tokenContract = merc721;
        _class = new VoterClassClosedERC721(address(_tokenContract), 2, 1);
    }

    function testOpenToMemberPropose() public {
        assertTrue(_class.isProposalApproved(_OWNER));
    }

    function testNotOpenToPartOwnerPropose() public {
        assertFalse(_class.isProposalApproved(_PARTOWNER));
    }

    function testClosedToPropose() public {
        assertFalse(_class.isProposalApproved(_NOTOWNER));
    }
}
