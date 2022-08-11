// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/VoterClassOpenVote.sol";

contract VoterClassOpenVoteTest is Test {
    address immutable _owner = address(0xffeeeeff);
    address immutable _notowner = address(0x55);
    address immutable _nobody = address(0x0);
    VoterClass _class;

    function setUp() public {
        _class = new VoterClassOpenVote();
    }

    function testIsVoter() public {
        assertTrue(_class.isVoter(_owner));
        assertTrue(_class.isVoter(_notowner));
    }

    function testVotesAvailable() public {
        assertEq(_class.votesAvailable(_owner), 1);
        assertEq(_class.votesAvailable(_notowner), 1);
    }

    function testFailIsVoterValidAddressRequired() public view {
        _class.isVoter(_nobody);
    }

    function testFailvotesAvailableValidAddressRequired() public view {
        _class.votesAvailable(_nobody);
    }
}
