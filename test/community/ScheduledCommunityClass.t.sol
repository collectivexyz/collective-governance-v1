// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../../contracts/community/ScheduledCommunityClass.sol";
import "../../contracts/community/CommunityClassOpenVote.sol";

contract ScheduledCommunityClassTest is Test {
    ScheduledCommunityClass private _class;

    function setUp() public {
        _class = new CommunityClassOpenVote(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY + 1 days,
            Constant.MAXIMUM_VOTE_DELAY - 2 seconds,
            Constant.MINIMUM_VOTE_DURATION + 1 days,
            Constant.MAXIMUM_VOTE_DURATION - 10 seconds
        );
    }

    function testMinimumVoteDelay() public {
        assertEq(Constant.MINIMUM_VOTE_DELAY + 1 days, _class.minimumVoteDelay());
    }

    function testMaximumVoteDelay() public {
        assertEq(Constant.MAXIMUM_VOTE_DELAY - 2 seconds, _class.maximumVoteDelay());
    }

    function testMinimumVoteDuration() public {
        assertEq(Constant.MINIMUM_VOTE_DURATION + 1 days, _class.minimumVoteDuration());
    }

    function testMaximumVoteDuration() public {
        assertEq(Constant.MAXIMUM_VOTE_DURATION - 10 seconds, _class.maximumVoteDuration());
    }
}
