// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/VoterClassOpenVote.sol";

contract VoterClassOpenVoteTest is Test {
    address private immutable _owner = address(0xffeeeeff);
    address private immutable _notowner = address(0x55);
    address private immutable _nobody = address(0x0);

    VoterClass private _class;

    function setUp() public {
        _class = new VoterClassOpenVote(1);
    }

    function testDiscoverVoteOwner() public {
        uint256[] memory shareList = _class.discover(_owner);
        assertEq(shareList.length, 1);
        assertEq(uint160(_owner), shareList[0]);
    }

    function testDiscoverVoteNotOwner() public {
        uint256[] memory shareList = _class.discover(_notowner);
        assertEq(shareList.length, 1);
        assertEq(uint160(_notowner), shareList[0]);
    }

    function testFailDiscoverVoteNobody() public view {
        _class.discover(_nobody);
    }

    function testConfirmOwner() public {
        uint256 shareCount = _class.confirm(_owner, uint160(_owner));
        assertEq(shareCount, 1);
    }

    function testFailConfirmWrongId() public {
        _class.confirm(_owner, uint160(_notowner));
    }

    function testConfirmNotOwner() public {
        uint256 shareCount = _class.confirm(_notowner, uint160(_notowner));
        assertEq(shareCount, 1);
    }

    function testFailConfirmNobody() public {
        _class.confirm(_nobody, 0x0);
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
}
