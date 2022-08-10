// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

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
        _tokenContract = new MockERC721(_owner, _tokenId);
        _class = new VoterClassERC721(address(_tokenContract));
    }

    function testIsVoter() public {
        assertTrue(_class.isVoter(_owner));
        assertFalse(_class.isVoter(_notowner));
    }

    function testVotesAvailable() public {
        assertEq(_class.votesAvailable(_owner), 1);
        assertEq(_class.votesAvailable(_notowner), 0);
    }

    function testFailIsVoterValidAddressRequired() public view {
        _class.isVoter(_nobody);
    }

    function testFailvotesAvailableValidAddressRequired() public view {
        _class.votesAvailable(_nobody);
    }
}
