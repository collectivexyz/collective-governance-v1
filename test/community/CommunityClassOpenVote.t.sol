// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable var-name-mixedcase
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../../contracts/community/CommunityClassOpenVote.sol";
import "../../contracts/access/Versioned.sol";

contract CommunityClassOpenVoteTest is Test {
    address private immutable _OWNER = address(0xffeeeeff);
    address private immutable _NOTOWNER = address(0x55);

    VoterClass private _class;

    function setUp() public {
        _class = new CommunityClassOpenVote(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
    }

    function testOpenToPropose() public {
        assertTrue(_class.canPropose(_OWNER));
        assertTrue(_class.canPropose(_NOTOWNER));
    }

    function testDiscoverVoteOwner() public {
        uint256[] memory shareList = _class.discover(_OWNER);
        assertEq(shareList.length, 1);
        assertEq(uint160(_OWNER), shareList[0]);
    }

    function testDiscoverVoteNotOwner() public {
        uint256[] memory shareList = _class.discover(_NOTOWNER);
        assertEq(shareList.length, 1);
        assertEq(uint160(_NOTOWNER), shareList[0]);
    }

    function testConfirmOwner() public {
        uint256 shareCount = _class.confirm(_OWNER, uint160(_OWNER));
        assertEq(shareCount, 1);
    }

    function testFailConfirmWrongId() public {
        _class.confirm(_OWNER, uint160(_NOTOWNER));
    }

    function testConfirmNotOwner() public {
        uint256 shareCount = _class.confirm(_NOTOWNER, uint160(_NOTOWNER));
        assertEq(shareCount, 1);
    }

    function testWeight() public {
        assertEq(1, _class.weight());
    }

    function testFinal() public {
        assertFalse(_class.isFinal());
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
        assertEq("CommunityClassOpenVote", _class.name());
    }
}
